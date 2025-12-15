<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('room_participants', function (Blueprint $table) {
            // Track cumulative points across all rounds in this room
            $table->integer('total_points')->default(0)->after('ready_for_voting_at');

            // Track if player has asked their mandatory minimum question this round
            $table->boolean('asked_mandatory_question')->default(false)->after('total_points');
        });
    }

    public function down(): void
    {
        Schema::table('room_participants', function (Blueprint $table) {
            $table->dropColumn(['total_points', 'asked_mandatory_question']);
        });
    }
};
