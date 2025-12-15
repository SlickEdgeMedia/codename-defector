<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('rounds', function (Blueprint $table) {
            // Round timer tracking
            $table->unsignedInteger('round_time_remaining_seconds')->nullable()->after('round_duration_seconds');
            $table->timestamp('round_timer_started_at')->nullable()->after('round_time_remaining_seconds');

            // Current turn tracking
            $table->foreignId('current_turn_participant_id')->nullable()->after('imposter_participant_id')->constrained('room_participants')->nullOnDelete();
            $table->enum('current_turn_phase', ['question', 'answer'])->nullable()->after('current_turn_participant_id');
            $table->unsignedTinyInteger('turn_time_remaining_seconds')->nullable()->after('current_turn_phase');
            $table->timestamp('turn_timer_started_at')->nullable()->after('turn_time_remaining_seconds');

            // Voting unlock tracking
            $table->boolean('voting_unlocked')->default(false)->after('turn_timer_started_at');
        });
    }

    public function down(): void
    {
        Schema::table('rounds', function (Blueprint $table) {
            $table->dropForeign(['current_turn_participant_id']);
            $table->dropColumn([
                'round_time_remaining_seconds',
                'round_timer_started_at',
                'current_turn_participant_id',
                'current_turn_phase',
                'turn_time_remaining_seconds',
                'turn_timer_started_at',
                'voting_unlocked',
            ]);
        });
    }
};
