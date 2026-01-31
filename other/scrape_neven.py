import requests
import pymysql
import time
import json
from datetime import datetime

# Database Configuration
db_config = {
    'host': '127.0.0.1',
    'port': 3306,
    'user': 'root',
    'password': 'qwert135',
    'db': 'line',
    'charset': 'utf8mb4',
    'cursorclass': pymysql.cursors.DictCursor
}

# Values for the requests
URL = 'https://neven.app/api/opportunities'
HEADERS = {
    'accept': 'application/json, text/plain, */*',
    'accept-language': 'zh,zh-CN;q=0.9,en;q=0.8,zh-TW;q=0.7,en-US;q=0.6,ja;q=0.5',
    'content-type': 'application/json',
    'dnt': '1',
    'origin': 'https://neven.app',
    'priority': 'u=1, i',
    'referer': 'https://neven.app/feed',
    'sec-ch-ua': '"Not(A:Brand";v="8", "Chromium";v="144", "Google Chrome";v="144"',
    'sec-ch-ua-mobile': '?0',
    'sec-ch-ua-platform': '"Windows"',
    'sec-fetch-dest': 'empty',
    'sec-fetch-mode': 'cors',
    'sec-fetch-site': 'same-origin',
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36'
}

# IMPORTANT: Update Cookies if they expire
COOKIES = {
    'JSESSIONID': 'E70239DF95523268F65EDF11738A64B5',
    '_ga': 'GA1.1.1068863585.1769833134',
    '_ga_CT2EC6QN3Y': 'GS2.1.s1769833133$o1$g1$t1769833283$j22$l0$h0'
}

CREATE_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS `opportunities` (
    `postId` TEXT COMMENT '帖子ID',
    `authorId` TEXT COMMENT '作者ID',
    `createdUTC` DATETIME COMMENT '创建时间(UTC)',
    `title` TEXT COMMENT '标题',
    `text` LONGTEXT COMMENT '正文内容',
    `subreddit` TEXT COMMENT '来源板块',
    `subredditSubscribers` INT COMMENT '板块订阅人数',
    `score` INT COMMENT '帖子得分',
    `numComments` INT COMMENT '评论数量',
    `opportunityDescription` TEXT COMMENT '机会描述',
    `likes` INT COMMENT '点赞数',
    `dislikes` INT COMMENT '不喜欢数',
    `url` TEXT COMMENT '原始链接',
    `likedByMe` BOOLEAN COMMENT '是否已赞',
    `dislikedByMe` BOOLEAN COMMENT '是否已踩',
    `savedByMe` BOOLEAN COMMENT '是否收藏',
    `category` TEXT COMMENT '分类',
    `is_new` BOOLEAN COMMENT '是否新机会'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Neven机会列表';
"""

INSERT_SQL = """
INSERT INTO `opportunities` (
    `postId`, `authorId`, `createdUTC`, `title`, `text`, `subreddit`, 
    `subredditSubscribers`, `score`, `numComments`, `opportunityDescription`, 
    `likes`, `dislikes`, `url`, `likedByMe`, `dislikedByMe`, `savedByMe`, 
    `category`, `is_new`
) VALUES (
    %s, %s, %s, %s, %s, %s, 
    %s, %s, %s, %s, 
    %s, %s, %s, %s, %s, %s, 
    %s, %s
)
"""

def get_connection():
    return pymysql.connect(**db_config)

def init_db():
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            # Create table if not exists
            cursor.execute(CREATE_TABLE_SQL)
            
            # Helper to add comments to existing table
            # Since MODIFY requires full definition, we map them here.
            alter_sql = """
            ALTER TABLE `opportunities` 
            MODIFY `postId` TEXT COMMENT '帖子ID',
            MODIFY `authorId` TEXT COMMENT '作者ID',
            MODIFY `createdUTC` DATETIME COMMENT '创建时间(UTC)',
            MODIFY `title` TEXT COMMENT '标题',
            MODIFY `text` LONGTEXT COMMENT '正文内容',
            MODIFY `subreddit` TEXT COMMENT '来源板块',
            MODIFY `subredditSubscribers` INT COMMENT '板块订阅人数',
            MODIFY `score` INT COMMENT '帖子得分',
            MODIFY `numComments` INT COMMENT '评论数量',
            MODIFY `opportunityDescription` TEXT COMMENT '机会描述',
            MODIFY `likes` INT COMMENT '点赞数',
            MODIFY `dislikes` INT COMMENT '不喜欢数',
            MODIFY `url` TEXT COMMENT '原始链接',
            MODIFY `likedByMe` BOOLEAN COMMENT '是否已赞',
            MODIFY `dislikedByMe` BOOLEAN COMMENT '是否已踩',
            MODIFY `savedByMe` BOOLEAN COMMENT '是否收藏',
            MODIFY `category` TEXT COMMENT '分类',
            MODIFY `is_new` BOOLEAN COMMENT '是否新机会',
            COMMENT = 'Neven机会列表';
            """
            cursor.execute(alter_sql)
            
            # Ensure utf8mb4
            cursor.execute("ALTER TABLE `opportunities` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;")
            cursor.execute("SET NAMES utf8mb4;")
        conn.commit()
    finally:
        conn.close()

def save_data(items):
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            for item in items:
                # Parse datetime - "2026-01-30T22:55:34"
                created_utc = item.get('createdUTC')
                # Map 'new' from JSON to 'is_new' in DB
                is_new = item.get('new')
                
                params = (
                    item.get('postId'),
                    item.get('authorId'),
                    created_utc,
                    item.get('title'),
                    item.get('text'),
                    item.get('subreddit'),
                    item.get('subredditSubscribers'),
                    item.get('score'),
                    item.get('numComments'),
                    item.get('opportunityDescription'),
                    item.get('likes'),
                    item.get('dislikes'),
                    item.get('url'),
                    item.get('likedByMe'),
                    item.get('dislikedByMe'),
                    item.get('savedByMe'),
                    item.get('category'),
                    is_new
                )
                cursor.execute(INSERT_SQL, params)
        conn.commit()
        print(f"Saved {len(items)} items to database.")
    except Exception as e:
        print(f"Error saving to database: {e}")
    finally:
        conn.close()

def scrape():
    page = 0
    size = 1000
    has_more = True

    while has_more:
        print(f"Fetching page {page}...")
        params = {
            'page': str(page),
            'size': str(size),
            'sort': 'is_new_opportunity,post.createdutc,desc'
        }
        
        # Payload based on curl
        data = {
            "startDate": "2025-08-04",
            "endDate": "2026-01-31",
            "subreddits": [],
            "categories": []
        }

        try:
            response = requests.post(
                URL, 
                params=params, 
                headers=HEADERS, 
                cookies=COOKIES, 
                json=data, # using json parameter automatically handles Content-Type and serialization
                timeout=10
            )

            if response.status_code == 200:
                result = response.json()
                content = result.get('content', [])
                
                if not content:
                    print("No more content found.")
                    has_more = False
                    break
                
                save_data(content)
                
                # Check pagination info
                total_pages = result.get('totalPages', 0)
                if page >= total_pages - 1:
                    has_more = False
                    print("Reached last page.")
                
                page += 1
                
                # Sleep to be polite
                time.sleep(1)
            else:
                print(f"Error: Status code {response.status_code}")
                print(response.text)
                has_more = False
                
        except Exception as e:
            print(f"Exception occurred: {e}")
            has_more = False

if __name__ == "__main__":
    print("Starting scraper...")
    try:
        init_db()
        scrape()
        print("Scraping completed.")
    except Exception as main_e:
        print(f"Critical error: {main_e}")
