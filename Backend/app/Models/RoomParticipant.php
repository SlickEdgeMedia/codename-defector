<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class RoomParticipant extends Model
{
    use HasFactory;

    protected $fillable = [
        'room_id',
        'user_id',
        'nickname',
        'is_host',
        'ready_at',
    ];

    protected $casts = [
        'is_host' => 'boolean',
        'ready_at' => 'datetime',
    ];

    public function room(): BelongsTo
    {
        return $this->belongsTo(Room::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
