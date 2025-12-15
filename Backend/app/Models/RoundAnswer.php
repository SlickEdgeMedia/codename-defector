<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class RoundAnswer extends Model
{
    use HasFactory;

    protected $fillable = [
        'question_id',
        'responder_participant_id',
        'text',
        'answered_at',
    ];

    protected $casts = [
        'answered_at' => 'datetime',
    ];

    public function question(): BelongsTo
    {
        return $this->belongsTo(RoundQuestion::class, 'question_id');
    }

    public function responder(): BelongsTo
    {
        return $this->belongsTo(RoomParticipant::class, 'responder_participant_id');
    }
}
