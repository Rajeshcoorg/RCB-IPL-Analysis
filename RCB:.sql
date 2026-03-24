------------------------------------------------------------------------------------------------------------------------------------------------------
--RCB IPL SQL Project
--Objective and Subjective Questions
--Presented By RAJESH M.M
-------------------------------------Objective Questions----------------------------------------------------------------------------------------------
use ipl;
--1.List the different dtypes of columns in table “ball_by_ball” (using information schema)

SELECT
    Column_Name,
    DATA_TYPE
FROM
    information_schema.COLUMNS
WHERE
	TABLE_NAME = 'ball_by_ball';
------------------------------------------------------------------------------------------------------------------------------------------
--2.What is the total number of runs scored in 1st season by RCB(bonus: also include the extra runs using the extra runs table)

SELECT 
    SUM(b.Runs_Scored) + SUM(e.Extra_Runs) AS total_runs
FROM ball_by_ball b
JOIN matches m 
    ON m.Match_Id = b.Match_Id
LEFT JOIN extra_runs e 
    ON e.Match_Id = b.Match_Id
   AND e.Innings_No = b.Innings_No
   AND e.Over_Id = b.Over_Id
   AND e.Ball_Id = b.Ball_Id
WHERE b.Team_Batting = 2
  AND m.Season_Id = (
        SELECT MIN(Season_Id)
        FROM matches
        WHERE Team_1 = 2 OR Team_2 = 2
  );
---------------------------------------------------------------------------------------------------------------------------------------
--3.How many players were more than the age of 25 during season 2014?

SELECT COUNT(DISTINCT p.Player_Id) AS Number_of_players
FROM matches m
JOIN player_match pm 
    ON m.Match_Id = pm.Match_Id
JOIN player p 
    ON pm.Player_Id = p.Player_Id
WHERE YEAR(m.Match_Date) = 2014
  AND (m.Team_1 = 2 OR m.Team_2 = 2)
  AND TIMESTAMPDIFF(YEAR, p.DOB, '2014-12-31') > 25;
---------------------------------------------------------------------------------------------------------------------------------------------
--4.How many matches did RCB win in 2013?

SELECT COUNT(*) AS matches_won
FROM matches
WHERE Season_Id = 6
  AND Match_Winner = 2;
----------------------------------------------------------------------------------------------------------------------------------------------
--5.List the top 10 players according to their strike rate in the last 4 seasons

SELECT 
    p.Player_Id,
    p.Player_Name,
    SUM(b.Runs_Scored) AS total_runs,
    COUNT(b.Ball_Id) AS balls_faced,
    ROUND((SUM(b.Runs_Scored) / COUNT(b.Ball_Id)) * 100, 2) AS Strike_Rate
FROM ball_by_ball b
JOIN matches m 
    ON m.Match_Id = b.Match_Id
JOIN player p 
    ON p.Player_Id = b.Striker
JOIN (
        SELECT Season_Id
        FROM matches
        GROUP BY Season_Id
        ORDER BY Season_Id DESC
        LIMIT 4
     ) s
     ON m.Season_Id = s.Season_Id
WHERE b.Team_Batting = 2
GROUP BY p.Player_Id, p.Player_Name
HAVING COUNT(b.Ball_Id) > 0
ORDER BY Strike_Rate DESC
LIMIT 10;
--------------------------------------------------------------------------------------------------------------------------------------------
--6.What are the average runs scored by each batsman considering all the seasons?

SELECT 
    p.Player_Id,
    p.Player_Name,
    ROUND(SUM(b.Runs_Scored) / COUNT(DISTINCT b.Match_Id), 2) AS avg_runs
FROM ball_by_ball b
JOIN player p 
    ON p.Player_Id = b.Striker
WHERE b.Team_Batting = 2
GROUP BY p.Player_Id, p.Player_Name
ORDER BY avg_runs DESC;
-------------------------------------------------------------------------------------------------------------------------------------------------
--7.What are the average wickets taken by each bowler considering all the seasons?

SELECT 
    p.Player_Id,
    p.Player_Name,
    ROUND(COUNT(*) / COUNT(DISTINCT b.Match_Id), 2) AS avg_wickets
FROM ball_by_ball b
JOIN wicket_taken w
    ON b.Match_Id = w.Match_Id
   AND b.Over_Id = w.Over_Id
   AND b.Ball_Id = w.Ball_Id
JOIN player p
    ON p.Player_Id = b.Bowler
WHERE b.Team_Bowling = 2
  AND w.Kind_Out != 'run out'
GROUP BY p.Player_Id, p.Player_Name
ORDER BY avg_wickets DESC;
----------------------------------------------------------------------------------------------------------------------------------------------------------
--8.List all the players who have average runs scored greater than the overall average and who have taken wickets greater than the overall average

SELECT 
    bat.Player_Id,
    bat.Player_Name,
    bat.avg_runs,
    bowl.avg_wickets
FROM
(
    SELECT 
        p.Player_Id,
        p.Player_Name,
        SUM(b.Runs_Scored) / COUNT(DISTINCT b.Match_Id) AS avg_runs
    FROM ball_by_ball b
    JOIN player p 
        ON p.Player_Id = b.Striker
    WHERE b.Team_Batting = 2
    GROUP BY p.Player_Id, p.Player_Name
) bat
JOIN
(
    SELECT 
        p.Player_Id,
        COUNT(*) / COUNT(DISTINCT b.Match_Id) AS avg_wickets
    FROM ball_by_ball b
    JOIN wicket_taken w
        ON b.Match_Id = w.Match_Id
       AND b.Over_Id = w.Over_Id
       AND b.Ball_Id = w.Ball_Id
    JOIN player p
        ON p.Player_Id = b.Bowler
    WHERE b.Team_Bowling = 2
      AND w.Kind_Out != 'run out'
    GROUP BY p.Player_Id
) bowl
ON bat.Player_Id = bowl.Player_Id
WHERE bat.avg_runs > (
        SELECT AVG(total_runs_per_match)
        FROM (
            SELECT SUM(Runs_Scored)/COUNT(DISTINCT Match_Id) AS total_runs_per_match
            FROM ball_by_ball
            WHERE Team_Batting = 2
            GROUP BY Striker
        ) t1
)
AND bowl.avg_wickets > (
        SELECT AVG(total_wickets_per_match)
        FROM (
            SELECT COUNT(*)/COUNT(DISTINCT b.Match_Id) AS total_wickets_per_match
            FROM ball_by_ball b
            JOIN wicket_taken w
              ON b.Match_Id = w.Match_Id
             AND b.Over_Id = w.Over_Id
             AND b.Ball_Id = w.Ball_Id
            WHERE b.Team_Bowling = 2
              AND w.Kind_Out != 'run out'
            GROUP BY b.Bowler
        ) t2
);
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
--9.Create a table rcb_record table that shows the wins and losses of RCB in an individual venue.

CREATE TABLE rcb_record AS
SELECT 
    v.Venue_Name,
    SUM(CASE WHEN m.Match_Winner = 2 THEN 1 ELSE 0 END) AS Matches_won,
    SUM(CASE 
            WHEN (m.Team_1 = 2 OR m.Team_2 = 2)
             AND m.Match_Winner != 2
            THEN 1
            ELSE 0
        END) AS Matches_lost
FROM matches m
JOIN venue v
    ON m.Venue_Id = v.Venue_Id
WHERE m.Team_1 = 2 OR m.Team_2 = 2
GROUP BY v.Venue_Name;
---------------------------------------------------------------------------------------------------------------------------------------------------
--10.What is the impact of bowling style on wickets taken?

SELECT 
    bs.Bowling_Skill,
    COUNT(*) AS total_wickets
FROM ball_by_ball b
JOIN wicket_taken w
    ON b.Match_Id = w.Match_Id
   AND b.Over_Id = w.Over_Id
   AND b.Ball_Id = w.Ball_Id
JOIN player p
    ON p.Player_Id = b.Bowler
JOIN bowling_style bs
    ON p.Bowling_Skill = bs.Bowling_Id
WHERE b.Team_Bowling = 2
  AND w.Kind_Out != 'run out'
GROUP BY bs.Bowling_Skill
ORDER BY total_wickets DESC;
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--11.Write the SQL query to provide a status of whether the performance of the team is better than the previous years performance on the basis of the number of runs scored by the team in the season and the number of wickets taken

WITH season_runs AS (
    SELECT 
        m.Season_Id,
        SUM(b.Runs_Scored) AS total_runs
    FROM matches m
    JOIN ball_by_ball b 
        ON m.Match_Id = b.Match_Id
    WHERE b.Team_Batting = 2
    GROUP BY m.Season_Id
),
season_wickets AS (
    SELECT 
        m.Season_Id,
        COUNT(*) AS total_wickets
    FROM matches m
    JOIN ball_by_ball b 
        ON m.Match_Id = b.Match_Id
    JOIN wicket_taken w
        ON w.Match_Id = b.Match_Id
       AND w.Over_Id = b.Over_Id
       AND w.Ball_Id = b.Ball_Id
    WHERE b.Team_Bowling = 2
      AND w.Kind_Out != 'run out'
    GROUP BY m.Season_Id
),
combined AS (
    SELECT 
        r.Season_Id,
        r.total_runs,
        w.total_wickets,
        LAG(r.total_runs) OVER (ORDER BY r.Season_Id) AS prev_runs,
        LAG(w.total_wickets) OVER (ORDER BY r.Season_Id) AS prev_wickets
    FROM season_runs r
    JOIN season_wickets w
        ON r.Season_Id = w.Season_Id
)
SELECT
    t.Team_Name,
    c.Season_Id,
    c.total_runs,
    c.total_wickets,
    CASE
        WHEN c.total_runs > c.prev_runs 
         AND c.total_wickets > c.prev_wickets THEN 'Better'
        WHEN c.total_runs < c.prev_runs 
         AND c.total_wickets < c.prev_wickets THEN 'Worse'
        ELSE 'Mixed'
    END AS performance_status
FROM combined c
JOIN team t
    ON t.Team_Id = 2
ORDER BY c.Season_Id;
---------------------------------------------------------------------------------------------------------------------------------------------------------------
--12.Can you derive more KPIs for the team strategy?
-----------------------------Win Percentage (Season Performance KPI)---------------------------------
SELECT 
    Season_Id,
    COUNT(*) AS total_matches,
    SUM(CASE WHEN Match_Winner = 2 THEN 1 ELSE 0 END) AS wins,
    ROUND((SUM(CASE WHEN Match_Winner = 2 THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) AS win_percentage
FROM matches
WHERE Team_1 = 2 OR Team_2 = 2
GROUP BY Season_Id
ORDER BY Season_Id;
---------------------------Batting Average Per Match (Team Strength)---------------------------------
SELECT 
    ROUND(SUM(Runs_Scored) / COUNT(DISTINCT Match_Id), 2) AS avg_runs_per_match
FROM ball_by_ball
WHERE Team_Batting = 2;
------------------------------Death Over Economy (Bowling Weakness Indicator)---------------------------
SELECT 
    ROUND(SUM(Runs_Scored) / COUNT(Over_Id), 2) AS death_over_economy
FROM ball_by_ball
WHERE Team_Bowling = 2
  AND Over_Id BETWEEN 16 AND 20;
--------------------------------Powerplay Run Rate (Aggression KPI)----------------------------------------
SELECT 
    ROUND(SUM(Runs_Scored) / COUNT(Over_Id), 2) AS powerplay_run_rate
FROM ball_by_ball
WHERE Team_Batting = 2
  AND Over_Id BETWEEN 1 AND 6;
--------------------------------Top 3 Dependency Ratio (Fragility KPI)----------------------------------------
SELECT 
    ROUND(
        (SUM(CASE WHEN Striker_Batting_Position <= 3 THEN Runs_Scored ELSE 0 END) 
        / SUM(Runs_Scored)) * 100,
        2
    ) AS top3_dependency_percentage
FROM ball_by_ball
WHERE Team_Batting = 2;
---------------------------------Bowling Strike Rate (Wicket Efficiency)-------------------------------------------
SELECT 
    ROUND(COUNT(b.Ball_Id) / COUNT(w.Match_Id), 2) AS bowling_strike_rate
FROM ball_by_ball b
JOIN wicket_taken w
    ON b.Match_Id = w.Match_Id
   AND b.Over_Id = w.Over_Id
   AND b.Ball_Id = w.Ball_Id
WHERE b.Team_Bowling = 2
  AND w.Kind_Out != 'run out';
-----------------------------------------------------------------------------------------------------------------------------------------------------------
--13.Using SQL, write a query to find out the average wickets taken by each bowler in each venue. Also, rank the gender according to the average value

SELECT 
    m.Venue_Id,
    v.Venue_Name,
    b.Bowler AS player_id,
    p.Player_Name AS bowler_name,
    ROUND(COUNT(w.Match_Id) / COUNT(DISTINCT m.Match_Id), 2) AS avg_wickets,
    RANK() OVER (
        PARTITION BY m.Venue_Id
        ORDER BY COUNT(w.Match_Id) / COUNT(DISTINCT m.Match_Id) DESC
    ) AS venue_rank
FROM matches m
JOIN venue v
    ON m.Venue_Id = v.Venue_Id
JOIN ball_by_ball b
    ON m.Match_Id = b.Match_Id
JOIN wicket_taken w
    ON w.Match_Id = b.Match_Id
   AND w.Over_Id = b.Over_Id
   AND w.Ball_Id = b.Ball_Id
JOIN player p
    ON b.Bowler = p.Player_Id
WHERE b.Team_Bowling = 2
  AND w.Kind_Out != 'run out'
GROUP BY 
    m.Venue_Id,
    v.Venue_Name,
    b.Bowler,
    p.Player_Name
ORDER BY 
    m.Venue_Id,
    venue_rank;
--------------------------------------------------------------------------------------------------------------------------------------------------------
--14.Which of the given players have consistently performed well in past seasons? (will you use any visualization to solve the problem)

SELECT 
    player_id,
    player_name,
    COUNT(*) AS seasons_played,
    ROUND(AVG(season_runs),2) AS avg_runs_per_season,
    ROUND(STDDEV(season_runs),2) AS performance_variation
FROM (
        SELECT 
            p.Player_Id AS player_id,
            p.Player_Name AS player_name,
            m.Season_Id,
            SUM(b.Runs_Scored) AS season_runs
        FROM ball_by_ball b
        JOIN matches m 
            ON b.Match_Id = m.Match_Id
        JOIN player p 
            ON b.Striker = p.Player_Id
        WHERE b.Team_Batting = 2
        GROUP BY p.Player_Id, p.Player_Name, m.Season_Id
     ) AS season_data
GROUP BY player_id, player_name
HAVING seasons_played >= 3
ORDER BY performance_variation ASC, avg_runs_per_season DESC;
---------------------------------------------------------------------------------------------------------------------------------------------
--15.Are there players whose performance is more suited to specific venues or conditions? (how would you present this using charts?)

SELECT 
    v.Venue_Name,
    p.Player_Name,
    ROUND(SUM(b.Runs_Scored),2) AS total_runs,
    ROUND(AVG(b.Runs_Scored),2) AS avg_runs_per_ball
FROM ball_by_ball b
JOIN matches m 
    ON b.Match_Id = m.Match_Id
JOIN venue v 
    ON m.Venue_Id = v.Venue_Id
JOIN player p 
    ON b.Striker = p.Player_Id
WHERE b.Team_Batting = 2
GROUP BY v.Venue_Name, p.Player_Name
HAVING total_runs > 200
ORDER BY v.Venue_Name, avg_runs_per_ball DESC;

-----------------------------------------------SUBJECTIVE QUESTIONS-------------------------------------------------------------------------------------------------------------------

--1.How does the toss decision affect the result of the match? (which visualizations could be used to present your answer better) And is the impact limited to only specific venues?

SELECT 
    t.Team_Name AS Toss_Winner,
    COUNT(*) AS Total_Matches,
    SUM(CASE 
            WHEN m.Match_Winner = m.Toss_Winner 
            THEN 1 
            ELSE 0 
        END) AS Matches_Won_After_Toss,
    ROUND(
        SUM(CASE 
                WHEN m.Match_Winner = m.Toss_Winner 
                THEN 1 
                ELSE 0 
            END) * 100.0 / COUNT(*),
        2
    ) AS Toss_Impact_Percentage
FROM Matches m
JOIN Team t 
    ON m.Toss_Winner = t.Team_Id
GROUP BY t.Team_Name
ORDER BY Toss_Impact_Percentage DESC;

SELECT 
    v.Venue_Name,
    COUNT(*) AS Total_Matches,
    SUM(CASE 
            WHEN m.Match_Winner = m.Toss_Winner 
            THEN 1 
            ELSE 0 
        END) AS Matches_Won_After_Toss,
    ROUND(
        SUM(CASE 
                WHEN m.Match_Winner = m.Toss_Winner 
                THEN 1 
                ELSE 0 
            END) * 100.0 / COUNT(*),
        2
    ) AS Toss_Win_Percentage
FROM Matches m
JOIN Venue v 
    ON m.Venue_Id = v.Venue_Id
GROUP BY v.Venue_Name
ORDER BY Toss_Win_Percentage DESC;
---------------------------------------------------------------------------------------------------------------------------------------------------------
--2.Suggest some of the players who would be best fit for the team.

SELECT 
    p.Player_Name,
    SUM(b.Runs_scored) AS total_runs
FROM Ball_by_Ball b
JOIN Player p 
    ON b.Striker = p.Player_Id
JOIN Matches m 
    ON b.Match_Id = m.Match_Id
WHERE (m.Team_1 = 2 OR m.Team_2 = 2)
AND b.Innings_No = 
    CASE 
        WHEN m.Team_1 = 2 THEN 1 
        ELSE 2 
    END
GROUP BY p.Player_Name
ORDER BY total_runs DESC
LIMIT 10;
---------------------------------------------------------------------------------------------------------------------------------------------
--3.What are some of the parameters that should be focused on whileselecting the players?

WITH player_stats AS (
    SELECT
        p.Player_Id,
        p.Player_Name,
        COUNT(DISTINCT b.Match_Id) AS matches_played,
        -- Batting Metrics
        SUM(CASE 
                WHEN b.Striker = p.Player_Id 
                THEN b.Runs_Scored 
                ELSE 0 
            END) AS total_runs,
        SUM(CASE 
                WHEN b.Striker = p.Player_Id 
                THEN 1 
                ELSE 0 
            END) AS balls_faced,
        -- Bowling Metrics
        SUM(CASE 
                WHEN b.Bowler = p.Player_Id 
                THEN 1 
                ELSE 0 
            END) AS balls_bowled,
        COUNT(CASE 
                WHEN b.Bowler = p.Player_Id 
                THEN w.Player_Out 
            END) AS wickets_taken,
        SUM(CASE 
                WHEN b.Bowler = p.Player_Id 
                THEN b.Runs_Scored 
                ELSE 0 
            END) AS runs_conceded
    FROM player p
    LEFT JOIN ball_by_ball b
        ON p.Player_Id IN (b.Striker, b.Bowler)
    LEFT JOIN wicket_taken w
        ON w.Match_Id = b.Match_Id
        AND w.Over_Id = b.Over_Id
        AND w.Ball_Id = b.Ball_Id
        AND w.Innings_No = b.Innings_No
        AND b.Bowler = p.Player_Id
    WHERE b.Team_Batting = 2  
    GROUP BY p.Player_Id, p.Player_Name
)
SELECT
    Player_Name,
    matches_played,
    ROUND(total_runs / NULLIF(matches_played, 0), 2) AS avg_runs,
    ROUND((total_runs / NULLIF(balls_faced, 0)) * 100, 2) AS strike_rate,
    ROUND(wickets_taken / NULLIF(matches_played, 0), 2) AS avg_wickets,
    ROUND(runs_conceded / NULLIF((balls_bowled / 6), 0), 2) AS economy,
    -- Composite Score
    ROUND(
        (total_runs / NULLIF(matches_played, 0)) * 0.35 +
        ((total_runs / NULLIF(balls_faced, 0)) * 100) * 0.25 +
        (wickets_taken / NULLIF(matches_played, 0)) * 0.25 -
        (runs_conceded / NULLIF((balls_bowled / 6), 0)) * 0.15
    , 2) AS selection_score
FROM player_stats
WHERE matches_played >= 20
ORDER BY selection_score DESC
LIMIT 15;

------------------------------------------------------------------------------------------------------------------------------------------------------
--4. Which players offer versatility in their skills and can contributeeffectively with both bat and ball? (can you visualize the data for the same)

SELECT 
    p.Player_Name,
    SUM(CASE WHEN b.Striker = p.Player_Id THEN b.runs_Scored ELSE 0 END) AS total_runs,
    COUNT(CASE WHEN b.Bowler = p.Player_Id THEN w.Player_Out END) AS total_wickets
FROM Player p
JOIN Player_Match pm 
    ON p.Player_Id = pm.Player_Id
JOIN Ball_by_Ball b 
    ON pm.Match_Id = b.Match_Id
LEFT JOIN Wicket_Taken w 
    ON b.Match_Id = w.Match_Id
    AND b.Over_Id = w.Over_Id
    AND b.Ball_Id = w.Ball_Id
WHERE pm.Team_Id = 2  -- replace with RCB team id
GROUP BY p.Player_Name
ORDER BY total_runs DESC;
--------------------------------------------------------------------------------------------------------------------------------------------------
5. Are there players whose presence positively influences the morale and performance of the team? (justify your answer using visualization)

SELECT 
    p.Player_Name,
    COUNT(DISTINCT m.Match_Id) AS matches_played,
    SUM(CASE WHEN m.Match_Winner = 2 THEN 1 ELSE 0 END) AS wins_with_player,
    ROUND(
        (SUM(CASE WHEN m.Match_Winner = 2 THEN 1 ELSE 0 END)
        / COUNT(DISTINCT m.Match_Id)) * 100,
    2) AS win_percentage_with_player
FROM matches m
JOIN player_match pm 
    ON m.Match_Id = pm.Match_Id
JOIN player p 
    ON pm.Player_Id = p.Player_Id
WHERE m.Team_1 = 2 OR m.Team_2 = 2
GROUP BY p.Player_Id, p.Player_Name
ORDER BY win_percentage_with_player DESC;
-------------------------------------------------------------------------------------------------------------------------------------------------
--8. Analyze the impact of home-ground advantage on team performance and identify strategies to maximize this advantage for RCB.

WITH Home_Ground AS (
    SELECT
        pm.Team_Id,
        c.City_Name,
        t.Team_Name,
        SUM(bb.Runs_Scored) * 1.0 / COUNT(bb.Ball_Id) AS Avg_Runs,
        COUNT(bb.Ball_Id) AS Total_Balls,
        COUNT(wt.Player_Out) AS Total_Wickets,
        COUNT(DISTINCT m.Match_Id) AS Total_Matches
    FROM Player_Match pm
    JOIN Ball_by_Ball bb ON bb.Match_Id = pm.Match_Id
    JOIN Matches m ON m.Match_Id = pm.Match_Id
    LEFT JOIN Wicket_Taken wt 
        ON wt.Match_Id = bb.Match_Id
        AND wt.Over_Id = bb.Over_Id
        AND wt.Ball_Id = bb.Ball_Id
        AND wt.Innings_No = bb.Innings_No
    JOIN Venue v 
        ON v.Venue_Id = m.Venue_Id
    JOIN City c 
        ON c.City_Id = v.City_Id
    JOIN Team t 
        ON t.Team_Id = pm.Team_Id
    WHERE t.Team_Id = 2   
    GROUP BY pm.Team_Id,
        c.City_Name,
        t.Team_Name
    ORDER BY Avg_Runs DESC )
SELECT
    City_Name,
    Team_Name,
    Avg_Runs,
    Total_Balls,
    Total_Wickets,
    Total_Matches
FROM Home_Ground;

--------------------------------------------------------------------------------------------------------------------------------------------------
--9. Come up with a visual and analytical analysis of the RCB's past season's performance and potential reasons for them not winning a trophy.
SELECT 
    m.Season_Id,
    COUNT(DISTINCT m.Match_Id) AS total_matches,
    SUM(CASE 
        WHEN m.Match_Winner = 2 THEN 1 
        ELSE 0 
    END) AS wins,
    COUNT(DISTINCT m.Match_Id) 
    - SUM(CASE WHEN m.Match_Winner = 2 THEN 1 ELSE 0 END) AS losses,
    ROUND(
        SUM(CASE WHEN m.Match_Winner = 2 THEN 1 ELSE 0 END) 
        / COUNT(DISTINCT m.Match_Id) * 100
    ,2) AS win_percentage,
    SUM(b.Runs_Scored) AS total_runs_scored
FROM matches m
JOIN ball_by_ball b
    ON m.Match_Id = b.Match_Id
WHERE (m.Team_1 = 2 OR m.Team_2 = 2)
AND b.Team_Batting = 2
GROUP BY m.Season_Id
ORDER BY m.Season_Id;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--11. In the "Match" table, some entries in the "Opponent_Team" column are incorrectly spelled as "Delhi_Capitals" instead of "Delhi_Daredevils". Write an SQL query to replace all occurrences of "Delhi_Capitals" with "Delhi_Daredevils".

UPDATE Team
SET Team_Name = 'Delhi Daredevils'
WHERE Team_Name = 'Delhi Capitals';

-----------------------------------------------------------------THANK YOU-------------------------------------------------------------------------------------

    