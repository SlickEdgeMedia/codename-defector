<?php

use App\Models\Room;
use App\Services\RoomEventPublisher;
use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Clean up inactive rooms every 5 minutes
Schedule::call(function () {
    $threshold = now()->subMinutes(30);

    $expiredRooms = Room::where('status', '!=', Room::STATUS_ENDED)
        ->where('last_active_at', '<', $threshold)
        ->get();

    foreach ($expiredRooms as $room) {
        $room->update(['status' => Room::STATUS_ENDED]);

        // Broadcast room.expired event to all participants
        $publisher = app(RoomEventPublisher::class);
        $publisher->broadcast('room.expired', $room, [
            'reason' => 'inactivity',
            'inactive_for_minutes' => 30,
        ]);
    }

    if ($expiredRooms->count() > 0) {
        info("Cleaned up {$expiredRooms->count()} inactive rooms");
    }
})->everyFiveMinutes()->name('cleanup:inactive-rooms');
