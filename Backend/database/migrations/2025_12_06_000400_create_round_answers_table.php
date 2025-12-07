<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('round_answers', function (Blueprint $table) {
            $table->id();
            $table->foreignId('question_id')->constrained('round_questions')->cascadeOnDelete();
            $table->foreignId('responder_participant_id')->constrained('room_participants')->cascadeOnDelete();
            $table->text('text');
            $table->timestamp('answered_at')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('round_answers');
    }
};
