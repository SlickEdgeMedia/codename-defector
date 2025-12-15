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

        // DEBUG: Log broadcast attempts
        \Log::info("Broadcasting event", ['type' => $type, 'room' => $room->code, 'payload' => $payload]);

        try {
            $result = Redis::connection(config('realtime.redis_connection'))
                ->publish(config('realtime.room_events_channel'), json_encode($message));
            \Log::info("Redis publish result", ['type' => $type, 'result' => $result]);
        } catch (Throwable $exception) {
            \Log::error("Redis publish failed", ['type' => $type, 'error' => $exception->getMessage()]);
            report($exception);
        }
    }
}
