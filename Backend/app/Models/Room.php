<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use App\Models\Round;

class Room extends Model
{
    use HasFactory;

    public const STATUS_LOBBY = 'lobby';
    public const STATUS_IN_ROUND = 'in_round';
    public const STATUS_ENDED = 'ended';

    protected $fillable = [
        'code',
        'host_user_id',
        'host_guest_token',
        'status',
        'max_players',
        'rounds',
        'discussion_seconds',
        'voting_seconds',
        'category',
        'round_duration_seconds',
        'last_active_at',
    ];

    protected $casts = [
        'status' => 'string',
        'max_players' => 'integer',
        'rounds' => 'integer',
        'discussion_seconds' => 'integer',
        'voting_seconds' => 'integer',
        'round_duration_seconds' => 'integer',
        'last_active_at' => 'datetime',
    ];

    protected static function booted(): void
    {
        static::creating(function (Room $room): void {
            $room->code = strtoupper($room->code);
            $room->status ??= self::STATUS_LOBBY;
        });
    }

    public function host(): BelongsTo
    {
        return $this->belongsTo(User::class, 'host_user_id');
    }

    public function participants(): HasMany
    {
        return $this->hasMany(RoomParticipant::class);
    }

    public function rounds(): HasMany
    {
        return $this->hasMany(Round::class);
    }
}
