<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('imposter_guesses', function (Blueprint $table) {
            // Drop foreign key constraint first
            $table->dropForeign(['word_id']);

            // Make word_id nullable
            $table->foreignId('word_id')->nullable()->change()->constrained('words');
        });
    }

    public function down(): void
    {
        Schema::table('imposter_guesses', function (Blueprint $table) {
            // Reverse: make word_id non-nullable again
            $table->dropForeign(['word_id']);
            $table->foreignId('word_id')->change()->constrained('words');
        });
    }
};
