<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // First, clean up any existing duplicates
        // Keep the oldest score record for each round_id + participant_id pair
        DB::statement('
            DELETE s1 FROM round_scores s1
            INNER JOIN round_scores s2
            WHERE s1.round_id = s2.round_id
            AND s1.participant_id = s2.participant_id
            AND s1.id > s2.id
        ');

        Schema::table('round_scores', function (Blueprint $table) {
            // Prevent duplicate score records for same participant in same round
            $table->unique(['round_id', 'participant_id'], 'unique_round_participant_score');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('round_scores', function (Blueprint $table) {
            $table->dropUnique('unique_round_participant_score');
        });
    }
};
