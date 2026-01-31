import pymysql
import json
import os

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

def get_connection():
    return pymysql.connect(**db_config)

def analyze():
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            print("Connected to database. Fetching ALL data...")

            # 1. Fetch ALL data (Title, Description, Subreddit, Score)
            sql_all = """
                SELECT title, opportunityDescription, subreddit, score
                FROM opportunities
            """
            cursor.execute(sql_all)
            all_data = cursor.fetchall()
            
            total_count = len(all_data)
            print(f"Processing {total_count} records...")

            # Analysis Containers
            subreddit_stats = {}  # {subreddit: {'count': 0, 'total_score': 0}}
            keyword_counts = {}   # {word: count}
            
            # Simple stop words list to ignore
            stop_words = set(['the', 'and', 'to', 'of', 'a', 'in', 'is', 'for', 'that', 'on', 'with', 'are', 'it', 'app', 'be', 'as', 'this', 'have', 'or', 'but', 'not', 'you', 'my', 'can', 'if', 'so', 'me', 'what', 'would', 'like', 'just', 'do', 'apps', 'there', 'an', 'at', 'from', 'software', 'tool', 'website', 'service', 'use', 'how', 'any', 'does', 'know', 'has', 'we', 'need', 'looking', 'want', 'find', 'make', 'one', 'get', 'some', 'time', 'help', 'search', 'way', 'better', 'best', 'good', 'something', 'is_new_opportunity', 'post', 'createdutc', 'desc', 'users', 'user', 'people'])

            for row in all_data:
                sub = row['subreddit']
                score = row['score'] if row['score'] else 0
                desc = row['opportunityDescription'] if row['opportunityDescription'] else ""
                title = row['title'] if row['title'] else ""

                # 1. Subreddit Stats
                if sub:
                    if sub not in subreddit_stats:
                        subreddit_stats[sub] = {'count': 0, 'total_score': 0}
                    subreddit_stats[sub]['count'] += 1
                    subreddit_stats[sub]['total_score'] += score

                # 2. Keyword Stats (Bigrams)
                # Combine title and desc for analysis
                text = (title + " " + desc).lower()
                # Remove punctuation roughly
                for char in '.,?!-:;"\'()[]':
                    text = text.replace(char, ' ')
                
                words = [w for w in text.split() if len(w) > 3 and w not in stop_words]
                
                # Count individual words
                for w in words:
                    keyword_counts[w] = keyword_counts.get(w, 0) + 1

            # Sort Results
            sorted_subreddits = sorted(subreddit_stats.items(), key=lambda x: x[1]['count'], reverse=True)[:30]
            sorted_keywords = sorted(keyword_counts.items(), key=lambda x: x[1], reverse=True)[:50]

            # Output Report
            output = f"FULL DATASET ANALYSIS REPORT\n"
            output += f"Total Records Analyzed: {total_count}\n"
            output += "="*50 + "\n\n"

            output += "### 1. Most Active Communities (Subreddits)\n"
            output += "Where are people asking for things most often?\n\n"
            output += "| Rank | Subreddit | Count | Total Score |\n"
            output += "|---|---|---|---|\n"
            for i, (sub, stats) in enumerate(sorted_subreddits, 1):
                output += f"| {i} | {sub} | {stats['count']} | {stats['total_score']} |\n"
            
            output += "\n### 2. Top Keywords (Hot Topics)\n"
            output += "Most frequent words in titles and descriptions (excluding common words):\n\n"
            for i, (word, count) in enumerate(sorted_keywords, 1):
                output += f"{i}. {word} ({count})\n"

            with open("full_analysis_results.txt", "w", encoding="utf-8") as f:
                f.write(output)
            
            print("Full analysis complete. Results saved to full_analysis_results.txt")

    finally:
        conn.close()

if __name__ == "__main__":
    analyze()
