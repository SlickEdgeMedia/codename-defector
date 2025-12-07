<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

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
            'participants' => RoomParticipantResource::collection($this->whenLoaded('participants')),
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
