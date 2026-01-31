-- Table Creation
CREATE TABLE IF NOT EXISTS `opportunities` (
    `postId` TEXT,
    `authorId` TEXT,
    `createdUTC` DATETIME,
    `title` TEXT,
    `text` TEXT,
    `subreddit` TEXT,
    `subredditSubscribers` INT,
    `score` INT,
    `numComments` INT,
    `opportunityDescription` TEXT,
    `likes` INT,
    `dislikes` INT,
    `url` TEXT,
    `likedByMe` BOOLEAN,
    `dislikedByMe` BOOLEAN,
    `savedByMe` BOOLEAN,
    `category` TEXT,
    `is_new` BOOLEAN
);
