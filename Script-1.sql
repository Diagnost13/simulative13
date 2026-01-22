WITH
  -- 1. Определяем самый ранний и самый поздний месяцы активности
  date_range AS (
    SELECT 
      DATE_TRUNC('month', MIN(start_date)) AS min_month,
      DATE_TRUNC('month', MAX(end_date)) AS max_month
    FROM (
      SELECT MIN(created_at) AS start_date, MAX(created_at) AS end_date FROM CodeSubmit WHERE user_id IN (SELECT id FROM Users WHERE company_id = 1)
      UNION ALL
      SELECT MIN(created_at), MAX(created_at) FROM CodeRun WHERE user_id IN (SELECT id FROM Users WHERE company_id = 1)
      UNION ALL
      SELECT MIN(created_at), MAX(created_at) FROM TestStart WHERE user_id IN (SELECT id FROM Users WHERE company_id = 1)
      UNION ALL
      SELECT MIN(date_joined), MAX(date_joined) FROM Users WHERE company_id = 1
    ) date_limits
  ),  
  -- 2. Генерируем все месяцы от самого раннего до самого позднего
  months AS (
    SELECT generate_series(
      (SELECT min_month FROM date_range),
      (SELECT max_month FROM date_range),
      interval '1 month'
    ) AS month_start
  ), 
  -- 3. Все пользователи компании id=1
  company_users AS (
    SELECT 
      id,
      username,
      date_joined,
      DATE_TRUNC('month', date_joined) AS join_month
    FROM Users
    WHERE company_id = 1
  ),  
  -- 4. Все активности пользователей компании id=1
  all_activities AS (
    -- CodeSubmit активность
    SELECT 
      cs.user_id,
      cs.created_at,
      'code_submit' AS action_type,
      cs.is_false,
      cs.problem_id
    FROM CodeSubmit cs
    WHERE cs.user_id IN (SELECT id FROM company_users)
    
    UNION ALL
    
    -- CodeRun активность
    SELECT 
      cr.user_id,
      cr.created_at,
      'code_run' AS action_type,
      1 AS is_false,
      cr.problem_id
    FROM CodeRun cr
    WHERE cr.user_id IN (SELECT id FROM company_users)
    
    UNION ALL    
    -- TestStart активность
    SELECT 
      ts.user_id,
      ts.created_at,
      'test_start' AS action_type,
      1 AS is_false,
      NULL AS problem_id
    FROM TestStart ts
    WHERE ts.user_id IN (SELECT id FROM company_users)
  ),  
  -- 5. Группируем активности по месяцам
  monthly_activities AS (
    SELECT 
      DATE_TRUNC('month', created_at) AS activity_month,
      user_id,
      action_type,
      is_false
    FROM all_activities
  ),
  -- 6. Накопительное количество пользователей по месяцам
  cumulative_users AS (
    SELECT
      m.month_start,
      COUNT(cu.id) AS total_users
    FROM months m
    LEFT JOIN company_users cu ON cu.date_joined <= m.month_start + interval '1 month' - interval '1 day'
    GROUP BY m.month_start
  ), 
  -- 7. Новые пользователи по месяцам
  new_users AS (
    SELECT
      m.month_start,
      COUNT(cu.id) AS new_users
    FROM months m
    LEFT JOIN company_users cu ON DATE_TRUNC('month', cu.date_joined) = m.month_start
    GROUP BY m.month_start
  )
-- 8. Основной запрос с динамикой по месяцам
SELECT 
  TO_CHAR(m.month_start, 'YYYY-MM') AS "Месяц",  
  -- Общее количество пользователей на конец месяца (накопительно)
  cu.total_users AS "Всего пользователей",  
  -- Новые пользователи в месяце
  nu.new_users AS "Новых пользователей", 
  -- Активность по типам (уникальные пользователи)
  COUNT(DISTINCT CASE 
    WHEN ma.action_type = 'code_submit' THEN ma.user_id
  END) AS "Решали задачи",  
  COUNT(DISTINCT CASE 
    WHEN ma.action_type = 'test_start' THEN ma.user_id
  END) AS "Проходили тесты",  
  COUNT(DISTINCT CASE 
    WHEN ma.action_type = 'code_run' THEN ma.user_id
  END) AS "Запускали код", 
  -- Статистика по успешности
  COUNT(DISTINCT CASE 
    WHEN ma.action_type = 'code_submit' AND ma.is_false = 0 THEN ma.user_id
  END) AS "Успешно решили задачи", 
  -- Общая активность (хотя бы одно действие любого типа)
  COUNT(DISTINCT ma.user_id) AS "Активных пользователей",  
  -- Количественные показатели
  COUNT(CASE WHEN ma.action_type = 'code_submit' THEN 1 END) AS "Всего попыток решения",
  COUNT(CASE WHEN ma.action_type = 'code_submit' AND ma.is_false = 0 THEN 1 END) AS "Успешных решений",
  COUNT(CASE WHEN ma.action_type = 'test_start' THEN 1 END) AS "Всего начатых тестов",
  COUNT(CASE WHEN ma.action_type = 'code_run' THEN 1 END) AS "Всего запусков кода",  
  -- Процент успешных решений
  ROUND(
    CASE 
      WHEN COUNT(CASE WHEN ma.action_type = 'code_submit' THEN 1 END) > 0 
      THEN 100.0 * COUNT(CASE WHEN ma.action_type = 'code_submit' AND ma.is_false = 0 THEN 1 END) / 
           COUNT(CASE WHEN ma.action_type = 'code_submit' THEN 1 END)
      ELSE 0 
    END, 1
  ) AS "Процент успешных решений",  
  -- Процент активных пользователей от общего количества
  ROUND(
    CASE 
      WHEN cu.total_users > 0
      THEN 100.0 * COUNT(DISTINCT ma.user_id) / cu.total_users
      ELSE 0 
    END, 1
  ) AS "Процент активных"
FROM months m
LEFT JOIN monthly_activities ma ON m.month_start = ma.activity_month
LEFT JOIN cumulative_users cu ON m.month_start = cu.month_start
LEFT JOIN new_users nu ON m.month_start = nu.month_start
GROUP BY m.month_start, cu.total_users, nu.new_users
ORDER BY m.month_start;