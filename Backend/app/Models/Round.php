<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Round extends Model
{
    use HasFactory;

    public const STATUS_PENDING = 'pending';
    public const STATUS_COUNTDOWN = 'countdown';
    public const STATUS_IN_PROGRESS = 'in_progress';
    public const STATUS_VOTING = 'voting';
    public const STATUS_SCORING = 'scoring';
    public const STATUS_ENDED = 'ended';

    protected $fillable = [
        'room_id',
        'round_number',
        'category_id',
        'word_id',
        'imposter_participant_id',
        'status',
        'round_duration_seconds',
        'started_at',
        'ended_at',
    ];

    protected $casts = [
        'started_at' => 'datetime',
        'ended_at' => 'datetime',
    ];

    public function room(): BelongsTo
    {
        return $this->belongsTo(Room::class);
    }

    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }

    public function word(): BelongsTo
    {
        return $this->belongsTo(Word::class);
    }

    public function imposter(): BelongsTo
    {
        return $this->belongsTo(RoomParticipant::class, 'imposter_participant_id');
    }

    public function questions(): HasMany
    {
        return $this->hasMany(RoundQuestion::class);
    }

    public function votes(): HasMany
    {
        return $this->hasMany(RoundVote::class);
    }

    public function scores(): HasMany
    {
        return $this->hasMany(RoundScore::class);
    }
}
