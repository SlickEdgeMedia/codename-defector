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
        Schema::table('round_questions', function (Blueprint $table) {
            $table->unsignedInteger('order')->default(0)->after('text');
            $table->enum('status', ['pending', 'in_progress', 'answered'])->default('pending')->after('order');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('round_questions', function (Blueprint $table) {
            $table->dropColumn('order');
            $table->dropColumn('status');
        });
    }
};
