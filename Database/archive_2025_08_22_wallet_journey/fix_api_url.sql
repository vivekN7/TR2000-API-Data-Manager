-- Fix API URL - remove /api/ prefix
UPDATE CONTROL_SETTINGS 
SET setting_value = 'https://equinor.pipespec-api.presight.com/'
WHERE setting_key = 'API_BASE_URL';

COMMIT;

-- Verify the change
SELECT setting_key, setting_value 
FROM CONTROL_SETTINGS 
WHERE setting_key = 'API_BASE_URL';

-- Also update the fetch functions to not add 'api/' prefix
-- The endpoints are now: /plants and /plants/{id}/issues