<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('imposter_guesses', function (Blueprint $table) {
            $table->id();
            $table->foreignId('round_id')->constrained('rounds')->cascadeOnDelete();
            $table->foreignId('imposter_participant_id')->constrained('room_participants')->cascadeOnDelete();
            $table->foreignId('word_id')->constrained('words');
            $table->boolean('correct')->default(false);
            $table->timestamp('guessed_at')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('imposter_guesses');
    }
};
