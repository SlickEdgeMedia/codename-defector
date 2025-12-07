<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('round_votes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('round_id')->constrained('rounds')->cascadeOnDelete();
            $table->foreignId('voter_participant_id')->constrained('room_participants')->cascadeOnDelete();
            $table->foreignId('target_participant_id')->constrained('room_participants')->cascadeOnDelete();
            $table->timestamp('cast_at')->nullable();
            $table->timestamps();

            $table->unique(['round_id', 'voter_participant_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('round_votes');
    }
};
