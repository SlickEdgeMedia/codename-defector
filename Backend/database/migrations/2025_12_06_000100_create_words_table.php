<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('words', function (Blueprint $table) {
            $table->id();
            $table->foreignId('category_id')->constrained('categories')->cascadeOnDelete();
            $table->string('text', 120);
            $table->timestamps();

            $table->unique(['category_id', 'text']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('words');
    }
};
