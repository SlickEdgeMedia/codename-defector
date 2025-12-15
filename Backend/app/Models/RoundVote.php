<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class RoundVote extends Model
{
    use HasFactory;

    protected $fillable = [
        'round_id',
        'voter_participant_id',
        'target_participant_id',
        'cast_at',
    ];

    protected $casts = [
        'cast_at' => 'datetime',
    ];

    public function round(): BelongsTo
    {
        return $this->belongsTo(Round::class);
    }

    public function voter(): BelongsTo
    {
        return $this->belongsTo(RoomParticipant::class, 'voter_participant_id');
    }

    public function target(): BelongsTo
    {
        return $this->belongsTo(RoomParticipant::class, 'target_participant_id');
    }
}
