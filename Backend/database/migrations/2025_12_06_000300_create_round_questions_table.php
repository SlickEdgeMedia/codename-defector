<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('round_questions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('round_id')->constrained('rounds')->cascadeOnDelete();
            $table->foreignId('asker_participant_id')->constrained('room_participants')->cascadeOnDelete();
            $table->foreignId('target_participant_id')->constrained('room_participants')->cascadeOnDelete();
            $table->text('text');
            $table->unsignedInteger('order')->default(0);
            $table->enum('status', ['pending', 'in_progress', 'answered'])->default('pending');
            $table->timestamp('asked_at')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('round_questions');
    }
};
