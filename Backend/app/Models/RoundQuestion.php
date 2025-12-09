<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;

class RoundQuestion extends Model
{
    use HasFactory;

    protected $fillable = [
        'round_id',
        'asker_participant_id',
        'target_participant_id',
        'text',
        'order',
        'status',
        'asked_at',
    ];

    protected $casts = [
        'asked_at' => 'datetime',
    ];

    public function round(): BelongsTo
    {
        return $this->belongsTo(Round::class);
    }

    public function asker(): BelongsTo
    {
        return $this->belongsTo(RoomParticipant::class, 'asker_participant_id');
    }

    public function target(): BelongsTo
    {
        return $this->belongsTo(RoomParticipant::class, 'target_participant_id');
    }

    public function answer(): HasOne
    {
        return $this->hasOne(RoundAnswer::class, 'question_id');
    }
}
