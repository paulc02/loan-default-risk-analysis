ALTER TABLE application_train ADD PRIMARY KEY (sk_id_curr);
ALTER TABLE application_test ADD PRIMARY KEY (sk_id_curr);
ALTER TABLE previous_application ADD PRIMARY KEY (sk_id_prev);
ALTER TABLE bureau ADD PRIMARY KEY (sk_id_bureau);

CREATE INDEX IF NOT EXISTS idx_bureau_curr ON bureau (sk_id_curr);
CREATE INDEX IF NOT EXISTS idx_bureau_balance_bureau ON bureau_balance (sk_id_bureau);
CREATE INDEX IF NOT EXISTS idx_prev_app_curr ON previous_application (sk_id_curr);
CREATE INDEX IF NOT EXISTS idx_pos_cash_prev ON pos_cash_balance (sk_id_prev);
CREATE INDEX IF NOT EXISTS idx_installments_prev ON installments_payments (sk_id_prev);
CREATE INDEX IF NOT EXISTS idx_credit_card_prev ON credit_card_balance (sk_id_prev);

ANALYZE;