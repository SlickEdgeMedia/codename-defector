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

        if ($round->status !== Round::STATUS_IN_PROGRESS) {
            return response()->json(['message' => 'Round not accepting questions'], 422);
        }

        $data = $request->validate([
            'target_participant_id' => 'required|integer|exists:room_participants,id',
            'text' => 'required|string|min:3|max:500',
        ]);

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

        $data = $request->validate([
            'question_id' => 'required|integer|exists:round_questions,id',
            'text' => 'required|string|min:1|max:500',
        ]);

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
            // all asked -> move to voting
            $round->update(['status' => Round::STATUS_VOTING]);
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

    public function vote(Request $request, int $roundId): JsonResponse
    {
        $round = Round::with(['room'])->findOrFail($roundId);
        $actor = $this->actor($request);
        $participant = $this->participant($round->room, $actor);

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

        return response()->json(['message' => 'Vote recorded', 'id' => $vote->id], 201);
    }

    public function imposterGuess(Request $request, int $roundId): JsonResponse
    {
        $round = Round::with('room')->findOrFail($roundId);
        $actor = $this->actor($request);
        $participant = $this->participant($round->room, $actor);

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

        return response()->json(['message' => 'Guess recorded', 'correct' => $correct, 'id' => $guess->id], 201);
    }

    public function results(Request $request, int $roundId): JsonResponse
    {
        $round = Round::with(['room', 'votes', 'scores', 'room.participants'])->findOrFail($roundId);
        $actor = $this->actor($request);
        $this->participant($round->room, $actor); // ensure member

        if ($round->status !== Round::STATUS_ENDED && $round->status !== Round::STATUS_SCORING) {
            $this->scoreRound($round);
        }

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

        return response()->json([
            'round_id' => $round->id,
            'status' => $round->status,
            'scores' => $scores,
            'imposter_participant_id' => $round->imposter_participant_id,
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
            $round->update(['status' => Round::STATUS_SCORING]);

            $imposterId = $round->imposter_participant_id;
            $votes = RoundVote::where('round_id', $round->id)->get();
            $totalVoters = $votes->count();
            $scores = [];

            $imposterVotes = $votes->where('target_participant_id', $imposterId);

            foreach ($votes as $vote) {
                $isCorrect = $vote->target_participant_id === $imposterId;
                $scores[] = [
                    'round_id' => $round->id,
                    'participant_id' => $vote->voter_participant_id,
                    'points' => $isCorrect ? 3 : -1,
                    'reason' => $isCorrect ? 'correct_vote' : 'incorrect_vote',
                    'created_at' => now(),
                    'updated_at' => now(),
                ];

                if (! $isCorrect) {
                    $scores[] = [
                        'round_id' => $round->id,
                        'participant_id' => $imposterId,
                        'points' => 1,
                        'reason' => 'others_incorrect_vote',
                        'created_at' => now(),
                        'updated_at' => now(),
                    ];
                }
            }

            // Imposter word guess
            $guess = ImposterGuess::where('round_id', $round->id)->first();
            $wordGuessPoints = 0;
            if ($guess) {
                $wordGuessPoints = $guess->correct ? 3 : -3;
                $scores[] = [
                    'round_id' => $round->id,
                    'participant_id' => $imposterId,
                    'points' => $wordGuessPoints,
                    'reason' => $guess->correct ? 'imposter_correct_guess' : 'imposter_wrong_guess',
                    'created_at' => now(),
                    'updated_at' => now(),
                ];
            }

            // Bonus for civilians wrong votes already captured; now imposter bonus for not being suspected
            $notSuspected = $totalVoters - $imposterVotes->count();
            if ($notSuspected > 0) {
                $scores[] = [
                    'round_id' => $round->id,
                    'participant_id' => $imposterId,
                    'points' => $notSuspected,
                    'reason' => 'not_suspected_bonus',
                    'created_at' => now(),
                    'updated_at' => now(),
                ];
            }

            if (! empty($scores)) {
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
