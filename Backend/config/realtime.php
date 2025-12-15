<?php

return [
    'room_events_channel' => env('ROOM_EVENTS_CHANNEL', 'imposter:rooms'),
    'redis_connection' => env('ROOM_EVENTS_REDIS_CONNECTION', 'default'),
];
