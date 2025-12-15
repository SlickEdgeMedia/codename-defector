<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class WordSeeder extends Seeder
{
    public function run(): void
    {
        $data = [
            'countries' => ['France', 'England', 'Japan', 'Brazil', 'Canada', 'Egypt', 'India', 'Germany', 'Kenya', 'Mexico', 'Norway', 'Spain', 'Sweden', 'Turkey', 'USA', 'China', 'Italy', 'Australia', 'Russia', 'Argentina'],
            'animals' => ['Lion', 'Elephant', 'Giraffe', 'Panda', 'Tiger', 'Kangaroo', 'Penguin', 'Zebra', 'Whale', 'Dolphin', 'Eagle', 'Fox', 'Owl', 'Shark', 'Bear', 'Rabbit', 'Crocodile', 'Hippo', 'Koala', 'Wolf'],
            'food' => ['Pizza', 'Burger', 'Sushi', 'Pasta', 'Taco', 'Curry', 'Salad', 'Steak', 'Pancake', 'Ramen', 'Dumpling', 'Burrito', 'Falafel', 'Paella', 'Donut', 'Croissant', 'Ice Cream', 'Cheesecake', 'Sandwich', 'BBQ'],
            'objects' => ['Laptop', 'Backpack', 'Umbrella', 'Guitar', 'Camera', 'Watch', 'Bicycle', 'Headphones', 'Book', 'Lamp', 'Wallet', 'Glasses', 'Bottle', 'Key', 'Chair', 'Table', 'Microwave', 'Phone', 'Pillow', 'Scissors'],
            'brands' => ['Nike', 'Apple', 'Samsung', 'Adidas', 'Coca-Cola', 'Pepsi', 'Google', 'Microsoft', 'Tesla', 'Toyota', 'Sony', 'Intel', 'Amazon', 'Facebook', 'BMW', 'Mercedes', 'Starbucks', 'Ikea', 'Netflix', 'Disney'],
        ];

        $now = now();

        foreach ($data as $slug => $words) {
            $category = DB::table('categories')->where('slug', $slug)->first();
            if (! $category) {
                continue;
            }

            foreach ($words as $text) {
                DB::table('words')->updateOrInsert(
                    ['category_id' => $category->id, 'text' => $text],
                    ['created_at' => $now, 'updated_at' => $now]
                );
            }
        }
    }
}
