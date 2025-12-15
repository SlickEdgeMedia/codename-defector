<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use App\Models\Round;
use App\Models\RoundQuestion;

/** @mixin \App\Models\Room */
class RoomResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $activeRound = $this->activeRound();
        $currentQuestion = $activeRound
            ? RoundQuestion::where('round_id', $activeRound->id)
                ->where('status', 'in_progress')
                ->orderByDesc('asked_at')
                ->first()
            : null;

        return [
            'id' => $this->id,
            'code' => $this->code,
            'status' => $this->status,
            'host_user_id' => $this->host_user_id,
            'host_guest_token' => $this->host_guest_token,
            'max_players' => $this->max_players,
            'rounds' => $this->rounds,
            'discussion_seconds' => $this->discussion_seconds,
            'voting_seconds' => $this->voting_seconds,
            'category' => $this->category,
            'round_duration_seconds' => $this->round_duration_seconds,
            'active_round_id' => $activeRound?->id,
            'active_round_status' => $activeRound?->status,
            'active_round_number' => $activeRound?->round_number,
            'active_round_started_at' => $activeRound?->started_at?->toIso8601String(),
            'current_question' => $currentQuestion ? [
                'id' => $currentQuestion->id,
                'asker_id' => $currentQuestion->asker_participant_id,
                'target_id' => $currentQuestion->target_participant_id,
                'text' => $currentQuestion->text,
                'order' => $currentQuestion->order,
                'status' => $currentQuestion->status,
            ] : null,
            'countdown_seconds' => Round::COUNTDOWN_SECONDS,
            'participants' => RoomParticipantResource::collection($this->whenLoaded('participants')),
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }

    private function activeRound()
    {
        return $this->rounds()->where('status', '!=', 'ended')->latest('id')->first();
    }
}
