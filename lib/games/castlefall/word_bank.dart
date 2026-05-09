class CfCategory {
  final String name;
  final List<String> words;
  const CfCategory(this.name, this.words);
}

/// Word bank for Castlefall. Each round picks a category, samples 16 words
/// from it, and chooses 2 of those 16 as the team words. Lists need to be
/// >= 16 words; the longer the list, the more variety between rounds.
const List<CfCategory> castlefallBank = [
  CfCategory('Food', [
    'Pizza', 'Sushi', 'Hamburger', 'Taco', 'Ramen', 'Pasta', 'Ice Cream',
    'Sandwich', 'Salad', 'Soup', 'Steak', 'Fried Chicken', 'Dumpling',
    'Croissant', 'Bagel', 'Donut', 'Pancake', 'Waffle', 'Omelette', 'Burrito',
    'Nachos', 'Kimchi', 'Biryani', 'Pho', 'Falafel', 'Gyro', 'Lasagna',
    'Risotto', 'Curry', 'Fish and Chips', 'Pad Thai', 'Bibimbap', 'Tikka',
    'Empanada', 'Hot Dog', 'Mac and Cheese', 'Quesadilla', 'Tiramisu',
    'Cheesecake', 'Gelato',
  ]),
  CfCategory('Sports', [
    'Soccer', 'Basketball', 'Football', 'Baseball', 'Tennis', 'Golf', 'Hockey',
    'Volleyball', 'Swimming', 'Track', 'Wrestling', 'Lacrosse', 'Rugby',
    'Cricket', 'Badminton', 'Table Tennis', 'Boxing', 'MMA', 'Gymnastics',
    'Skateboarding', 'Surfing', 'Skiing', 'Snowboarding', 'Climbing', 'Archery',
    'Fencing', 'Rowing', 'Cycling', 'Bowling', 'Diving', 'Curling', 'Polo',
    'Squash', 'Pickleball',
  ]),
  CfCategory('Movies', [
    'Inception', 'Titanic', 'Avatar', 'The Godfather', 'Pulp Fiction',
    'The Dark Knight', 'Forrest Gump', 'Star Wars', 'Jurassic Park',
    'The Matrix', 'Avengers Endgame', 'Spider-Man', 'Toy Story', 'Finding Nemo',
    'The Lion King', 'Frozen', 'Shrek', 'Harry Potter', 'Lord of the Rings',
    'Interstellar', 'Joker', 'Parasite', 'Get Out', 'La La Land', 'Whiplash',
    'Goodfellas', 'Fight Club', 'Shawshank Redemption', 'Gladiator', 'Top Gun',
    'Dune', 'Oppenheimer', 'Barbie', 'Everything Everywhere',
  ]),
  CfCategory('Animals', [
    'Dog', 'Cat', 'Elephant', 'Lion', 'Tiger', 'Bear', 'Panda', 'Kangaroo',
    'Koala', 'Giraffe', 'Zebra', 'Horse', 'Cow', 'Pig', 'Chicken', 'Duck',
    'Rabbit', 'Deer', 'Wolf', 'Fox', 'Eagle', 'Owl', 'Penguin', 'Dolphin',
    'Whale', 'Shark', 'Octopus', 'Turtle', 'Snake', 'Frog', 'Cheetah', 'Hippo',
    'Rhino', 'Monkey', 'Sloth', 'Otter', 'Hawk', 'Falcon',
  ]),
  CfCategory('Countries', [
    'USA', 'Canada', 'Mexico', 'Brazil', 'Argentina', 'UK', 'France', 'Germany',
    'Italy', 'Spain', 'Russia', 'China', 'Japan', 'South Korea', 'India',
    'Australia', 'Egypt', 'South Africa', 'Nigeria', 'Kenya', 'Saudi Arabia',
    'Turkey', 'Greece', 'Sweden', 'Norway', 'Netherlands', 'Vietnam',
    'Thailand', 'Indonesia', 'Philippines', 'Portugal', 'Ireland', 'Poland',
    'Switzerland', 'Belgium', 'Denmark', 'Finland',
  ]),
  CfCategory('Anime', [
    'Naruto', 'One Piece', 'Attack on Titan', 'Demon Slayer', 'Jujutsu Kaisen',
    'My Hero Academia', 'Death Note', 'Dragon Ball', 'Bleach',
    'Fullmetal Alchemist', 'Hunter x Hunter', 'Tokyo Ghoul', 'Spy x Family',
    'Chainsaw Man', 'One Punch Man', 'Sword Art Online', 'Cowboy Bebop',
    'Neon Genesis Evangelion', 'Code Geass', 'Mob Psycho 100', 'Haikyuu',
    'Black Clover', 'Fairy Tail', 'Vinland Saga', 'Made in Abyss', 'Re:Zero',
    'Steins;Gate', 'Erased', 'Your Name', 'Spirited Away', 'Bleach',
    'Frieren', 'Solo Leveling',
  ]),
  CfCategory('Celebrities', [
    'Taylor Swift', 'Beyoncé', 'Drake', 'Kanye West', 'Rihanna',
    'Ariana Grande', 'Justin Bieber', 'Selena Gomez', 'Tom Cruise',
    'Leonardo DiCaprio', 'Brad Pitt', 'Will Smith', 'Dwayne Johnson',
    'Kim Kardashian', 'Kylie Jenner', 'Zendaya', 'Timothée Chalamet',
    'Tom Holland', 'Robert Downey Jr', 'Scarlett Johansson', 'Margot Robbie',
    'Ryan Reynolds', 'Keanu Reeves', 'Elon Musk', 'Mark Zuckerberg',
    'Oprah Winfrey', 'Ellen DeGeneres', 'LeBron James', 'Cristiano Ronaldo',
    'Lionel Messi', 'Pedro Pascal', 'Sydney Sweeney', 'Bad Bunny',
  ]),
  CfCategory('Pop Culture', [
    'TikTok', 'Instagram', 'YouTube', 'Twitch', 'Netflix', 'Spotify',
    'Snapchat', 'Twitter', 'Discord', 'Roblox', 'Minecraft', 'Fortnite',
    'Among Us', 'Genshin Impact', 'Marvel', 'DC Comics', 'Disney', 'Pixar',
    'K-pop', 'BTS', 'Stranger Things', 'The Office', 'Friends',
    'Game of Thrones', 'Squid Game', 'Wednesday', 'Barbie', 'Oppenheimer',
    'MrBeast', 'Met Gala', 'AI', 'ChatGPT', 'Threads',
  ]),
  CfCategory('Places', [
    'Beach', 'Mountain', 'Forest', 'Desert', 'Park', 'Library', 'Museum',
    'Airport', 'Train Station', 'Hospital', 'School', 'University', 'Church',
    'Mosque', 'Temple', 'Stadium', 'Concert Hall', 'Movie Theater', 'Gym',
    'Mall', 'Grocery Store', 'Restaurant', 'Cafe', 'Hotel', 'Casino',
    'Amusement Park', 'Zoo', 'Aquarium', 'Bowling Alley', 'Arcade', 'Skatepark',
    'Office Building', 'Construction Site', 'Farm', 'Lighthouse', 'Castle',
    'Cave', 'Volcano', 'Island', 'Pier',
  ]),
  CfCategory('Jobs', [
    'Doctor', 'Nurse', 'Teacher', 'Lawyer', 'Engineer', 'Accountant',
    'Firefighter', 'Police Officer', 'Chef', 'Pilot', 'Flight Attendant',
    'Surgeon', 'Dentist', 'Veterinarian', 'Architect', 'Plumber', 'Electrician',
    'Carpenter', 'Mechanic', 'Farmer', 'Banker', 'Real Estate Agent',
    'Journalist', 'Photographer', 'Graphic Designer', 'Software Developer',
    'Scientist', 'Professor', 'Librarian', 'Therapist', 'Pharmacist',
    'Bartender', 'Barista', 'Lifeguard', 'Personal Trainer', 'Athlete',
    'Actor', 'Musician', 'DJ', 'Streamer',
  ]),
  CfCategory('BCA', [
    'Mr. Bolton', 'Dr. Abramson', 'Mrs. Mendelsohn', 'Mr. Isecke', 'Dr. Carter',
    'Senora Seltzer', 'Mr. Bonanomi', 'Mrs. Crimmel', 'Ms. Kaba', 'Mr. Smith',
    'Mrs. Acuna', 'Mr. Madden', 'Mrs. Wallace', 'Ms. Kim', 'Dr. Todd Crane',
    'Dr. Laura Crane', 'Mrs. Sorrentino', 'Mr. Hodroski', 'Mr. Russo',
    'Dr. Zubov', 'Ms. Pinke', 'Dr. Bath', 'Mr. Davis', 'Dr. Sabio',
    'Mr. Pinyan', 'Mr. King', 'Mrs. Villanova', 'Dr. Pinto',
  ]),
];
