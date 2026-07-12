-- db/migrations/001_init_notifications.sql

CREATE TABLE notification_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id UUID NOT NULL,
    channel VARCHAR(20) NOT NULL, -- 'EMAIL', 'SMS', 'PUSH'
    template_name VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL, -- 'PENDING', 'SENT', 'FAILED'
    error_details TEXT,
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_notification_recipient ON notification_logs(recipient_id);