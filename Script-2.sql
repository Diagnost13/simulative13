SELECT 
  c.id AS "ID компании",
  c.name AS "Название компании",
  COUNT(DISTINCT u.id) AS "Всего пользователей", 
  -- Активность за период
  COUNT(DISTINCT CASE 
    WHEN EXISTS (
      SELECT 1 FROM CodeSubmit cs 
      WHERE cs.user_id = u.id 
    ) THEN u.id
  END) AS "Решали задачи",  
  COUNT(DISTINCT CASE 
    WHEN EXISTS (
      SELECT 1 FROM TestStart ts 
      WHERE ts.user_id = u.id 
    ) THEN u.id
  END) AS "Проходили тесты",  
  -- Статистика по успешности
  COUNT(DISTINCT CASE 
    WHEN EXISTS (
      SELECT 1 FROM CodeSubmit cs 
      WHERE cs.user_id = u.id 
        AND cs.is_false = 0
    ) THEN u.id
  END) AS "Успешно решили задачи",
  -- Общая активность
  COUNT(DISTINCT CASE 
    WHEN EXISTS (
      SELECT 1 FROM CodeSubmit cs WHERE cs.user_id = u.id
      UNION ALL
      SELECT 1 FROM CodeRun cr WHERE cr.user_id = u.id
      UNION ALL
      SELECT 1 FROM TestStart ts WHERE ts.user_id = u.id
    ) THEN u.id
  END) AS "Активных пользователей"
FROM Company c
LEFT JOIN Users u ON c.id = u.company_id
WHERE u.id IS NOT NULL
GROUP BY c.id, c.name
ORDER BY "Всего пользователей" DESC;