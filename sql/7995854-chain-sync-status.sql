/* Protocol Signal Lab — Chain Sync Status
   Short columns for readable Vault heartbeat (one table viz). */
WITH tip AS (
    SELECT
        MAX(number) AS block_num,
        MAX(time) AS block_time
    FROM ethereum.blocks
    WHERE DATE(time) >= CURRENT_DATE - INTERVAL '2' DAY
)
SELECT
    CAST(block_num AS VARCHAR) AS last_block,
    format_datetime(CURRENT_TIMESTAMP, 'MMM dd HH:mm') AS queried,
    CASE
        WHEN date_diff('minute', block_time, CURRENT_TIMESTAMP) <= 30 THEN 'FRESH'
        WHEN date_diff('minute', block_time, CURRENT_TIMESTAMP) <= 180 THEN 'OK'
        ELSE 'LAG'
    END AS freshness
FROM tip
