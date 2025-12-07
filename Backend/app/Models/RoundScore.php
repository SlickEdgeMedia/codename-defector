<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class RoundScore extends Model
{
    use HasFactory;

    protected $fillable = [
        'round_id',
        'participant_id',
        'points',
        'reason',
    ];

    public function round(): BelongsTo
    {
        return $this->belongsTo(Round::class);
    }

    public function participant(): BelongsTo
    {
        return $this->belongsTo(RoomParticipant::class, 'participant_id');
    }
}
