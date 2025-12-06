<?php

namespace App\Services;

use App\Models\Room;
use Illuminate\Support\Facades\Redis;
use Throwable;

class RoomEventPublisher
{
    public function broadcast(string $type, Room $room, array $payload = []): void
    {
        $message = [
            'type' => $type,
            'room_code' => $room->code,
            'room_status' => $room->status,
            'timestamp' => now()->toIso8601String(),
            'payload' => $payload,
        ];

        try {
            Redis::connection(config('realtime.redis_connection'))
                ->publish(config('realtime.room_events_channel'), json_encode($message));
        } catch (Throwable $exception) {
            report($exception);
        }
    }
}
