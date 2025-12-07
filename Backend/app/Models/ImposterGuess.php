<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ImposterGuess extends Model
{
    use HasFactory;

    protected $fillable = [
        'round_id',
        'imposter_participant_id',
        'word_id',
        'correct',
        'guessed_at',
    ];

    protected $casts = [
        'correct' => 'boolean',
        'guessed_at' => 'datetime',
    ];

    public function round(): BelongsTo
    {
        return $this->belongsTo(Round::class);
    }

    public function imposter(): BelongsTo
    {
        return $this->belongsTo(RoomParticipant::class, 'imposter_participant_id');
    }

    public function word(): BelongsTo
    {
        return $this->belongsTo(Word::class);
    }
}
