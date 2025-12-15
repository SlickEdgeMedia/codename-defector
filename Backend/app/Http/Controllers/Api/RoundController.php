<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Models\ImposterGuess;
use App\Models\Room;
use App\Models\RoomParticipant;
use App\Models\Round;
use App\Models\RoundAnswer;
use App\Models\RoundQuestion;
use App\Models\RoundScore;
use App\Models\RoundVote;
use App\Models\Word;
use App\Services\RoomEventPublisher;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class RoundController extends Controller
{
    public function __construct(private readonly RoomEventPublisher $publisher)
    {
    }

    public function start(Request $request, string $code): JsonResponse
    {
        $countdownSeconds = Round::COUNTDOWN_SECONDS;
        $room = Room::where('code', strtoupper($code))->with('participants')->firstOrFail();
        $actor = $this->actor($request);
        $this->assertHost($room, $actor);

        if ($room->status !== Room::STATUS_LOBBY) {
            return response()->json(['message' => 'Room not in lobby state'], 422);
        }

        $participants = $room->participants;
        if ($participants->count() < 3) {
            return response()->json(['message' => 'Need at least 3 players'], 422);
        }

        $allReady = $participants->every(fn ($p) => $p->ready_at !== null);
        if (! $allReady) {
            return response()->json(['message' => 'All players must be ready'], 422);
        }

        $round = DB::transaction(function () use ($room, $participants) {
            $category = Category::where('slug', $room->category)->first()
                ?? Category::first();

            if (! $category) {
                abort(422, 'No category available to start a round.');
            }

            $word = Word::where('category_id', $category->id)->inRandomOrder()->first();
            $imposter = $participants->random();
            $roundNumber = $room->rounds()->count() + 1;

            $round = Round::create([
                'room_id' => $room->id,
                'round_number' => $roundNumber,
                'category_id' => $category->id,
                'word_id' => $word?->id,
                'imposter_participant_id' => $imposter->id,
                'status' => Round::STATUS_IN_PROGRESS,
                'round_duration_seconds' => $room->round_duration_seconds,
                'started_at' => now(),
            ]);

            $room->update([
                'status' => Room::STATUS_IN_ROUND,
                'last_active_at' => now(),
            ]);

            $askOrder = $participants->shuffle()->values();
            foreach ($askOrder as $index => $p) {
                RoundQuestion::create([
                    'round_id' => $round->id,
                    'asker_participant_id' => $p->id,
                    'target_participant_id' => $this->pickTarget($participants, $p)->id,
                    'text' => '',
                    'order' => $index + 1,
                    'status' => $index === 0 ? 'in_progress' : 'pending',
                ]);
            }

            return $round;
        });

        $firstQuestion = RoundQuestion::where('round_id', $round->id)->orderBy('order')->first();
        $firstQuestionPayload = $firstQuestion ? [
            'question_id' => $firstQuestion->id,
            'asker_id' => $firstQuestion->asker_participant_id,
            'target_id' => $firstQuestion->target_participant_id,
            'order' => $firstQuestion->order,
        ] : null;

        $this->publisher->broadcast('round.started', $room, [
            'round_id' => $round->id,
            'round_number' => $round->round_number,
            'duration' => $round->round_duration_seconds,
            'category' => $room->category,
            'started_at' => $round->started_at?->toIso8601String(),
            'countdown_seconds' => $countdownSeconds,
            'first_question' => $firstQuestionPayload,
        ]);

        if ($firstQuestion) {
            $this->publisher->broadcast('round.question_turn', $room, [
                'round_id' => $round->id,
                'question_id' => $firstQuestion->id,
                'asker_id' => $firstQuestion->asker_participant_id,
                'target_id' => $firstQuestion->target_participant_id,
                'order' => $firstQuestion->order,
            ]);
        }

        return response()->json([
            'message' => 'Round started',
            'round_id' => $round->id,
            'round_number' => $round->round_number,
            'started_at' => $round->started_at?->toIso8601String(),
            'countdown_seconds' => $countdownSeconds,
            'round_duration_seconds' => $round->round_duration_seconds,
            'first_question' => $firstQuestionPayload,
        ], 201);
    }

    public function role(Request $request, int $roundId): JsonResponse
    {
        $round = Round::with(['room', 'word.category'])->findOrFail($roundId);
        $actor = $this->actor($request);
        $participant = $this->participant($round->room, $actor);

        $isImposter = $round->imposter_participant_id === $participant->id;
        $categoryWords = Word::where('category_id', $round->category_id)
            ->get(['id', 'text'])
            ->map(fn (Word $word) => ['id' => $word->id, 'text' => $word->text]);

        return response()->json([
            'round_id' => $round->id,
            'round_number' => $round->round_number,
            'role' => $isImposter ? 'imposter' : 'civilian',
            'category' => $round->word?->category?->name,
            'word' => $isImposter ? null : $round->word?->text,
            'word_list' => $isImposter ? $categoryWords : null,
        ]);
    }

    public function askQuestion(Request $request, int $roundId): JsonResponse
    {
        $round = Round::with(['room', 'questions'])->findOrFail($roundId);
        $actor = $this->actor($request);
        $participant = $this->participant($round->room, $actor);

        $round->room->touch('last_active_at');

        if ($round->status !== Round::STATUS_IN_PROGRESS) {
            return response()->json(['message' => 'Round not accepting questions'], 422);
        }

        $data = $request->validate([
            'target_participant_id' => 'required|integer|exists:room_participants,id',
            'text' => 'required|string|min:1|max:500',
        ]);

        // Custom validation: reject questions shorter than 3 chars unless it's a timeout marker
        $questionText = trim($data['text']);
        if (strlen($questionText) < 3 && $questionText !== '[Timed out]') {
            return response()->json(['message' => 'Question must be at least 3 characters'], 422);
        }

        $current = RoundQuestion::where('round_id', $round->id)
            ->where('status', 'in_progress')
            ->first();

        if (! $current || $current->asker_participant_id !== $participant->id) {
            return response()->json(['message' => 'Not your turn to ask'], 422);
        }

        $targetId = $data['target_participant_id'];
        $target = RoomParticipant::find($targetId);
        if (! $target) {
            return response()->json(['message' => 'Target not found'], 422);
        }
        if ($target->id === $participant->id) {
            return response()->json(['message' => 'Cannot target yourself'], 422);
        }

        $current->target_participant_id = $targetId;
        $current->text = $data['text'];
        $current->asked_at = now();

        // Check if this is a timed-out question
        $isTimedOut = trim($data['text']) === '[Timed out]';

        if ($isTimedOut) {
            // Mark as answered immediately (skipped due to timeout)
            $current->status = 'answered';
            $current->save();

            // Broadcast the timed-out question
            $this->publisher->broadcast('round.question', $round->room, [
                'round_id' => $round->id,
                'question_id' => $current->id,
                'asker_id' => $participant->id,
                'asker_nickname' => $participant->nickname,
                'target_id' => $targetId,
                'target_nickname' => $target?->nickname,
                'text' => $data['text'],
            ]);

            // Immediately move to next question
            $next = RoundQuestion::where('round_id', $round->id)
                ->where('status', 'pending')
                ->orderBy('order')
                ->first();

            if ($next) {
                $next->update(['status' => 'in_progress']);
                $this->publisher->broadcast('round.question_turn', $round->room, [
                    'round_id' => $round->id,
                    'question_id' => $next->id,
                    'asker_id' => $next->asker_participant_id,
                    'target_id' => $next->target_participant_id,
                    'order' => $next->order,
                ]);
            } else {
                // All questions done - transition to voting
                $round->status = Round::STATUS_VOTING;
                $round->save();

                $this->publisher->broadcast('round.phase', $round->room, [
                    'round_id' => $round->id,
                    'phase' => 'voting',
                ]);
            }
        } else {
            // Normal question - wait for answer
            $current->status = 'in_progress';
            $current->save();

            $this->publisher->broadcast('round.question', $round->room, [
                'round_id' => $round->id,
                'question_id' => $current->id,
                'asker_id' => $participant->id,
                'asker_nickname' => $participant->nickname,
                'target_id' => $targetId,
                'target_nickname' => $target?->nickname,
                'text' => $data['text'],
            ]);
        }

        // Ensure room snapshot reflects the updated target/text promptly
        $round->touch();

        return response()->json([
            'message' => 'Question asked',
            'id' => $current->id,
            'asker_id' => $participant->id,
            'asker_nickname' => $participant->nickname,
            'target_id' => $targetId,
            'target_nickname' => $target?->nickname,
            'text' => $data['text'],
            'order' => $current->order,
            'status' => $current->status,
        ], 201);
    }

    public function answerQuestion(Request $request, int $roundId): JsonResponse
    {
        $round = Round::with('room')->findOrFail($roundId);
        $actor = $this->actor($request);
        $participant = $this->participant($round->room, $actor);

        $round->room->touch('last_active_at');

        // Status check - must be in progress
        if ($round->status !== Round::STATUS_IN_PROGRESS) {
            return response()->json(['message' => 'Round not in progress'], 422);
        }

        $data = $request->validate([
            'question_id' => 'required|integer|exists:round_questions,id',
            'text' => 'required|string|min:1|max:500',
        ]);

        // Custom validation: reject answers shorter than 2 chars unless it's a timeout marker
        // (allows "No", "Yes", etc.)
        $answerText = trim($data['text']);
        if (strlen($answerText) < 2 && $answerText !== '[Timed out]') {
            return response()->json(['message' => 'Answer must be at least 2 characters'], 422);
        }

        $question = RoundQuestion::where('round_id', $round->id)
            ->where('id', $data['question_id'])
            ->firstOrFail();

        if ($question->target_participant_id !== $participant->id) {
            return response()->json(['message' => 'Not your question to answer'], 403);
        }

        if ($question->answer) {
            return response()->json(['message' => 'Already answered'], 422);
        }

        $answer = RoundAnswer::create([
            'question_id' => $question->id,
            'responder_participant_id' => $participant->id,
            'text' => $data['text'],
            'answered_at' => now(),
        ]);

        $question->update(['status' => 'answered']);

        $next = RoundQuestion::where('round_id', $round->id)
            ->where('status', 'pending')
            ->orderBy('order')
            ->first();

        if ($next) {
            $next->update(['status' => 'in_progress']);
            $this->publisher->broadcast('round.question_turn', $round->room, [
                'round_id' => $round->id,
                'question_id' => $next->id,
                'asker_id' => $next->asker_participant_id,
                'target_id' => $next->target_participant_id,
                'order' => $next->order,
            ]);
        } else {
            // All questions answered - transition to voting phase automatically
            $round->status = Round::STATUS_VOTING;
            $round->save();

            $this->publisher->broadcast('round.phase', $round->room, [
                'round_id' => $round->id,
                'phase' => 'voting',
            ]);
        }

        $this->publisher->broadcast('round.answer', $round->room, [
            'round_id' => $round->id,
            'question_id' => $question->id,
            'responder_id' => $participant->id,
            'responder_nickname' => $participant->nickname,
            'text' => $data['text'],
        ]);

        return response()->json(['message' => 'Answered', 'id' => $answer->id], 201);
    }

    public function readyForVoting(Request $request, int $roundId): JsonResponse
    {
        $round = Round::with(['room.participants'])->findOrFail($roundId);
        $actor = $this->actor($request);
        $participant = $this->participant($round->room, $actor);

        $round->room->touch('last_active_at');

        // Mark participant as ready for voting
        $participant->ready_for_voting_at = now();
        $participant->save();

        // Refresh participants to get updated ready status
        $round->room->load('participants');

        // Broadcast ready status
        $this->publisher->broadcast('round.ready_for_voting', $round->room, [
            'round_id' => $round->id,
            'participant_id' => $participant->id,
            'nickname' => $participant->nickname,
            'ready_count' => $round->room->participants->whereNotNull('ready_for_voting_at')->count(),
            'total_count' => $round->room->participants->count(),
        ]);

        // Check if all participants are ready
        $allReady = $round->room->participants->every(fn($p) => $p->ready_for_voting_at !== null);

        if ($allReady) {
            // Reset ready status and transition to voting
            $round->room->participants->each(function ($p) {
                $p->ready_for_voting_at = null;
                $p->save();
            });

            // Transition to voting phase
            $round->status = Round::STATUS_VOTING;
            $round->save();

            $this->publisher->broadcast('round.phase', $round->room, [
                'round_id' => $round->id,
                'phase' => 'voting',
            ]);
        }

        return response()->json(['message' => 'Marked as ready', 'all_ready' => $allReady]);
    }

    public function vote(Request $request, int $roundId): JsonResponse
    {
        $round = Round::with(['room.participants'])->findOrFail($roundId);
        $actor = $this->actor($request);
        $participant = $this->participant($round->room, $actor);

        $round->room->touch('last_active_at');

        $data = $request->validate([
            'target_participant_id' => 'required|integer|exists:room_participants,id',
        ]);

        if ($round->status !== Round::STATUS_VOTING) {
            return response()->json(['message' => 'Not in voting phase'], 422);
        }

        if ($round->imposter_participant_id === $participant->id) {
            return response()->json(['message' => 'Imposter cannot vote'], 422);
        }

        if ($participant->id === $data['target_participant_id']) {
            return response()->json(['message' => 'Cannot vote yourself'], 422);
        }

        $existing = RoundVote::where('round_id', $round->id)
            ->where('voter_participant_id', $participant->id)
            ->first();

        if ($existing) {
            return response()->json(['message' => 'Already voted'], 422);
        }

        $vote = RoundVote::create([
            'round_id' => $round->id,
            'voter_participant_id' => $participant->id,
            'target_participant_id' => $data['target_participant_id'],
            'cast_at' => now(),
        ]);

        $totals = RoundVote::where('round_id', $round->id)
            ->select('target_participant_id', DB::raw('COUNT(*) as votes'))
            ->groupBy('target_participant_id')
            ->get()
            ->map(fn ($row) => [
                'participant_id' => $row->target_participant_id,
                'votes' => (int) $row->votes,
            ]);

        $this->publisher->broadcast('round.votes_updated', $round->room, [
            'round_id' => $round->id,
            'totals' => $totals,
        ]);

        // Check if all civilians have voted (excluding imposter)
        $civilians = $round->room->participants->where('id', '!=', $round->imposter_participant_id);
        $civilianVotes = RoundVote::where('round_id', $round->id)->count();
        $allCiviliansVoted = $civilianVotes >= $civilians->count();

        // Check if imposter has guessed or skipped
        $imposterGuessed = ImposterGuess::where('round_id', $round->id)->exists();

        if ($allCiviliansVoted && $imposterGuessed) {
            // All civilians voted AND imposter guessed/skipped - transition to results
            $this->scoreRound($round);
        }

        return response()->json(['message' => 'Vote recorded', 'id' => $vote->id], 201);
    }

    public function imposterGuess(Request $request, int $roundId): JsonResponse
    {
        $round = Round::with('room')->findOrFail($roundId);
        $actor = $this->actor($request);
        $participant = $this->participant($round->room, $actor);

        $round->room->touch('last_active_at');

        // Status check - must be in voting phase
        if ($round->status !== Round::STATUS_VOTING) {
            return response()->json(['message' => 'Not in voting phase'], 422);
        }

        if ($round->imposter_participant_id !== $participant->id) {
            return response()->json(['message' => 'Only imposter can guess'], 403);
        }

        $data = $request->validate([
            'word_id' => 'required|integer|exists:words,id',
        ]);

        $existing = ImposterGuess::where('round_id', $round->id)->first();
        if ($existing) {
            return response()->json(['message' => 'Guess already made this round'], 422);
        }

        $correct = $round->word_id === $data['word_id'];

        $guess = ImposterGuess::create([
            'round_id' => $round->id,
            'imposter_participant_id' => $participant->id,
            'word_id' => $data['word_id'],
            'correct' => $correct,
            'guessed_at' => now(),
        ]);

        $this->publisher->broadcast('round.imposter_guess', $round->room, [
            'round_id' => $round->id,
            'word_id' => $data['word_id'],
            'correct' => $correct,
            'word_text' => Word::find($data['word_id'])?->text,
        ]);

        // Check if all civilians have voted
        $round->load('room.participants');
        $civilians = $round->room->participants->where('id', '!=', $round->imposter_participant_id);
        $civilianVotes = RoundVote::where('round_id', $round->id)->count();
        $allCiviliansVoted = $civilianVotes >= $civilians->count();

        if ($allCiviliansVoted) {
            // All civilians voted AND imposter guessed - transition to results
            $this->scoreRound($round);
        }

        return response()->json(['message' => 'Guess recorded', 'correct' => $correct, 'id' => $guess->id], 201);
    }

    public function skipGuess(Request $request, int $roundId): JsonResponse
    {
        $round = Round::with('room.participants')->findOrFail($roundId);
        $actor = $this->actor($request);
        $participant = $this->participant($round->room, $actor);

        $round->room->touch('last_active_at');

        // Status check - must be in voting phase
        if ($round->status !== Round::STATUS_VOTING) {
            return response()->json(['message' => 'Not in voting phase'], 422);
        }

        if ($round->imposter_participant_id !== $participant->id) {
            return response()->json(['message' => 'Only imposter can skip'], 403);
        }

        // Check if already guessed or skipped
        $existing = ImposterGuess::where('round_id', $round->id)->first();
        if ($existing) {
            return response()->json(['message' => 'Already guessed/skipped this round'], 422);
        }

        // Create a "skip" record (word_id = null, correct = false)
        $guess = ImposterGuess::create([
            'round_id' => $round->id,
            'imposter_participant_id' => $participant->id,
            'word_id' => null,
            'correct' => false,
            'guessed_at' => now(),
        ]);

        $this->publisher->broadcast('round.imposter_skip', $round->room, [
            'round_id' => $round->id,
        ]);

        // Check if all civilians have voted
        $civilians = $round->room->participants->where('id', '!=', $round->imposter_participant_id);
        $civilianVotes = RoundVote::where('round_id', $round->id)->count();
        $allCiviliansVoted = $civilianVotes >= $civilians->count();

        if ($allCiviliansVoted) {
            // All civilians voted AND imposter skipped - transition to results
            $this->scoreRound($round);
        }

        return response()->json(['message' => 'Skipped', 'id' => $guess->id], 201);
    }

    public function results(Request $request, int $roundId): JsonResponse
    {
        $round = Round::with(['room', 'votes', 'scores', 'room.participants'])->findOrFail($roundId);
        $actor = $this->actor($request);
        $this->participant($round->room, $actor); // ensure member

        if ($round->status !== Round::STATUS_ENDED && $round->status !== Round::STATUS_SCORING) {
            $this->scoreRound($round);
        }

        // Get current round scores
        $scores = RoundScore::where('round_id', $round->id)
            ->with('participant')
            ->get()
            ->map(function (RoundScore $score) {
                return [
                    'participant_id' => $score->participant_id,
                    'nickname' => $score->participant?->nickname,
                    'points' => $score->points,
                    'reason' => $score->reason,
                ];
            });

        // Calculate cumulative scores for all participants in this room across all rounds
        $cumulativeScores = RoundScore::select('participant_id')
            ->selectRaw('SUM(points) as total_points')
            ->whereIn('round_id', function ($query) use ($round) {
                $query->select('id')
                    ->from('rounds')
                    ->where('room_id', $round->room_id);
            })
            ->groupBy('participant_id')
            ->get()
            ->mapWithKeys(function ($item) {
                return [$item->participant_id => (int)$item->total_points];
            })
            ->toArray();

        // Check if imposter guessed the word correctly
        $imposterGuess = ImposterGuess::where('round_id', $round->id)->first();
        $imposterGuessedCorrectly = $imposterGuess && $imposterGuess->word_id !== null && $imposterGuess->correct;

        return response()->json([
            'round_id' => $round->id,
            'status' => $round->status,
            'scores' => $scores,
            'cumulative_scores' => $cumulativeScores,
            'imposter_participant_id' => $round->imposter_participant_id,
            'imposter_guessed_correctly' => $imposterGuessedCorrectly,
        ]);
    }

    private function actor(Request $request): array
    {
        if ($request->attributes->get('user')) {
            $user = $request->attributes->get('user');

            return ['type' => 'user', 'id' => $user->id, 'name' => $user->name];
        }

        $guest = $request->attributes->get('guest');
        if ($guest) {
            return ['type' => 'guest', 'token' => $guest->token, 'name' => $guest->nickname];
        }

        abort(401, 'Unauthenticated.');
    }

    private function participant(Room $room, array $actor): RoomParticipant
    {
        $query = RoomParticipant::where('room_id', $room->id);
        $query = $actor['type'] === 'user'
            ? $query->where('user_id', $actor['id'])
            : $query->where('guest_token', $actor['token']);

        $participant = $query->first();

        if (! $participant) {
            abort(403, 'Not in this room');
        }

        return $participant;
    }

    private function assertHost(Room $room, array $actor): void
    {
        $isHost = $actor['type'] === 'user'
            ? $room->host_user_id === $actor['id']
            : $room->host_guest_token === ($actor['token'] ?? null);

        if (! $isHost) {
            abort(403, 'Only host can perform this action.');
        }
    }

    private function scoreRound(Round $round): void
    {
        DB::transaction(function () use ($round) {
            // IDEMPOTENCY CHECK: Refresh and verify round isn't already scoring/ended
            $round->refresh();

            if ($round->status === Round::STATUS_SCORING || $round->status === Round::STATUS_ENDED) {
                // Already scored or scoring, skip silently
                return;
            }

            $round->update(['status' => Round::STATUS_SCORING]);

            $imposterId = $round->imposter_participant_id;
            $votes = RoundVote::where('round_id', $round->id)->get();
            $imposterVotes = $votes->where('target_participant_id', $imposterId);

            // Track points per participant
            $participantPoints = [];

            // Score civilians based on their votes
            foreach ($votes as $vote) {
                $voterId = $vote->voter_participant_id;
                $isCorrect = $vote->target_participant_id === $imposterId;

                // Civilian gets points for their vote
                $participantPoints[$voterId] = ($participantPoints[$voterId] ?? 0) + ($isCorrect ? 5 : -1);

                // Imposter gets +1 for each wrong vote against others
                if (!$isCorrect) {
                    $participantPoints[$imposterId] = ($participantPoints[$imposterId] ?? 0) + 1;
                }
            }

            // Score imposter's word guess
            $guess = ImposterGuess::where('round_id', $round->id)->first();
            if ($guess && $guess->word_id !== null) {
                // Only score if they actually guessed (not skipped)
                // Correct guess: +2, Wrong guess: 0 (no penalty)
                $participantPoints[$imposterId] = ($participantPoints[$imposterId] ?? 0) + ($guess->correct ? 2 : 0);
            }

            // Create one score entry per participant with total points
            $scores = [];
            foreach ($participantPoints as $participantId => $points) {
                $scores[] = [
                    'round_id' => $round->id,
                    'participant_id' => $participantId,
                    'points' => $points,
                    'reason' => $participantId === $imposterId ? 'imposter_total' : 'civilian_total',
                    'created_at' => now(),
                    'updated_at' => now(),
                ];
            }

            if (!empty($scores)) {
                RoundScore::insert($scores);
            }

            $round->update(['status' => Round::STATUS_ENDED, 'ended_at' => now()]);
            $round->room()->update(['status' => Room::STATUS_LOBBY]);

            $this->publisher->broadcast('round.results', $round->room, [
                'round_id' => $round->id,
            ]);
        });
    }

    private function pickTarget($participants, RoomParticipant $asker): RoomParticipant
    {
        $others = $participants->where('id', '!=', $asker->id)->values();

        return $others->isNotEmpty() ? $others->random() : $asker;
    }
}
