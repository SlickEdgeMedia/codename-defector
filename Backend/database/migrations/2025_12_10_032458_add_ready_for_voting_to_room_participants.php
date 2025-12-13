<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('room_participants', function (Blueprint $table) {
            $table->timestamp('ready_for_voting_at')->nullable()->after('ready_at');
        });
    }

    public function down(): void
    {
        Schema::table('room_participants', function (Blueprint $table) {
            $table->dropColumn('ready_for_voting_at');
        });
    }
};
