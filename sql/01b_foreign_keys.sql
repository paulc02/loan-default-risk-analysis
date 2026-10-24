-- bureau_balance -> bureau
ALTER TABLE bureau_balance DROP CONSTRAINT IF EXISTS fk_bureau_balance_bureau;
ALTER TABLE bureau_balance
  ADD CONSTRAINT fk_bureau_balance_bureau
  FOREIGN KEY (sk_id_bureau) REFERENCES bureau (sk_id_bureau) NOT VALID;

-- pos_cash_balance -> previous_application
ALTER TABLE pos_cash_balance DROP CONSTRAINT IF EXISTS fk_pos_cash_prev;
ALTER TABLE pos_cash_balance
  ADD CONSTRAINT fk_pos_cash_prev
  FOREIGN KEY (sk_id_prev) REFERENCES previous_application (sk_id_prev) NOT VALID;

-- installments_payments -> previous_application
ALTER TABLE installments_payments DROP CONSTRAINT IF EXISTS fk_installments_prev;
ALTER TABLE installments_payments
  ADD CONSTRAINT fk_installments_prev
  FOREIGN KEY (sk_id_prev) REFERENCES previous_application (sk_id_prev) NOT VALID;

-- credit_card_balance -> previous_application
ALTER TABLE credit_card_balance DROP CONSTRAINT IF EXISTS fk_credit_card_prev;
ALTER TABLE credit_card_balance
  ADD CONSTRAINT fk_credit_card_prev
  FOREIGN KEY (sk_id_prev) REFERENCES previous_application (sk_id_prev) NOT VALID;

-- OPTIONAL VALIDATIONS
-- ALTER TABLE bureau_balance VALIDATE CONSTRAINT fk_bureau_balance_bureau;
-- ALTER TABLE pos_cash_balance VALIDATE CONSTRAINT fk_pos_cash_prev;
-- ALTER TABLE installments_payments VALIDATE CONSTRAINT fk_installments_prev;
-- ALTER TABLE credit_card_balance VALIDATE CONSTRAINT fk_credit_card_prev;