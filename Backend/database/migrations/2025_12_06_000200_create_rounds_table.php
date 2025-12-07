<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('rounds', function (Blueprint $table) {
            $table->id();
            $table->foreignId('room_id')->constrained('rooms')->cascadeOnDelete();
            $table->unsignedInteger('round_number')->default(1);
            $table->foreignId('category_id')->constrained('categories');
            $table->foreignId('word_id')->nullable()->constrained('words');
            $table->foreignId('imposter_participant_id')->nullable()->constrained('room_participants')->nullOnDelete();
            $table->enum('status', ['pending', 'countdown', 'in_progress', 'voting', 'scoring', 'ended'])->default('pending');
            $table->unsignedSmallInteger('round_duration_seconds')->default(300);
            $table->timestamp('started_at')->nullable();
            $table->timestamp('ended_at')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('rounds');
    }
};
