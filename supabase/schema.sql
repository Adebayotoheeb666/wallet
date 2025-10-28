-- ==========================================
-- CRYPTOVAULT SUPABASE SCHEMA
-- ==========================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ==========================================
-- 1. USERS TABLE
-- ==========================================
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  auth_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  email VARCHAR(255) UNIQUE NOT NULL,
  username VARCHAR(100),
  full_name VARCHAR(255),
  profile_picture_url TEXT,
  phone_number VARCHAR(20),
  country VARCHAR(100),
  is_verified BOOLEAN DEFAULT FALSE,
  email_verified_at TIMESTAMP WITH TIME ZONE,
  two_factor_enabled BOOLEAN DEFAULT FALSE,
  preferred_currency VARCHAR(10) DEFAULT 'USD',
  notification_preferences JSONB DEFAULT '{
    "email_on_transaction": true,
    "email_on_withdrawal": true,
    "email_on_price_alert": false,
    "push_notifications": true
  }'::jsonb,
  kyc_status VARCHAR(50) DEFAULT 'pending', -- pending, verified, rejected
  kyc_submitted_at TIMESTAMP WITH TIME ZONE,
  kyc_verified_at TIMESTAMP WITH TIME ZONE,
  account_status VARCHAR(50) DEFAULT 'active', -- active, suspended, closed
  last_login TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  deleted_at TIMESTAMP WITH TIME ZONE
);

-- Create index for email
CREATE INDEX idx_users_email ON public.users(email);
CREATE INDEX idx_users_auth_id ON public.users(auth_id);

-- ==========================================
-- 2. SESSIONS TABLE
-- ==========================================
CREATE TABLE IF NOT EXISTS public.sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  token_hash VARCHAR(255) UNIQUE NOT NULL,
  ip_address INET,
  user_agent TEXT,
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_sessions_user_id ON public.sessions(user_id);
CREATE INDEX idx_sessions_expires_at ON public.sessions(expires_at);

-- ==========================================
-- 3. WALLETS TABLE
-- ==========================================
CREATE TABLE IF NOT EXISTS public.wallets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  wallet_address VARCHAR(255) NOT NULL,
  wallet_type VARCHAR(50) NOT NULL, -- coinbase, metamask, ledger, trezor
  label VARCHAR(100),
  is_primary BOOLEAN DEFAULT FALSE,
  balance_usd DECIMAL(20, 2) DEFAULT 0,
  balance_btc DECIMAL(20, 8) DEFAULT 0,
  last_synced TIMESTAMP WITH TIME ZONE,
  connected_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  disconnected_at TIMESTAMP WITH TIME ZONE,
  is_active BOOLEAN DEFAULT TRUE,
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, wallet_address)
);

CREATE INDEX idx_wallets_user_id ON public.wallets(user_id);
CREATE INDEX idx_wallets_address ON public.wallets(wallet_address);
CREATE INDEX idx_wallets_is_primary ON public.wallets(user_id, is_primary);

-- ==========================================
-- 4. ASSETS TABLE
-- ==========================================
CREATE TABLE IF NOT EXISTS public.assets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  wallet_id UUID NOT NULL REFERENCES public.wallets(id) ON DELETE CASCADE,
  symbol VARCHAR(20) NOT NULL, -- BTC, ETH, USDC, ADA
  name VARCHAR(100) NOT NULL,
  balance DECIMAL(20, 8) NOT NULL DEFAULT 0,
  balance_usd DECIMAL(20, 2) DEFAULT 0,
  price_usd DECIMAL(20, 2),
  price_change_24h DECIMAL(10, 2),
  price_change_7d DECIMAL(10, 2),
  price_change_30d DECIMAL(10, 2),
  chain VARCHAR(50), -- ethereum, bitcoin, cardano, etc
  contract_address VARCHAR(255),
  last_synced TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, wallet_id, symbol)
);

CREATE INDEX idx_assets_user_id ON public.assets(user_id);
CREATE INDEX idx_assets_wallet_id ON public.assets(wallet_id);
CREATE INDEX idx_assets_symbol ON public.assets(symbol);

-- ==========================================
-- 5. TRANSACTIONS TABLE
-- ==========================================
CREATE TABLE IF NOT EXISTS public.transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  wallet_id UUID NOT NULL REFERENCES public.wallets(id) ON DELETE CASCADE,
  tx_hash VARCHAR(255) UNIQUE,
  tx_type VARCHAR(50) NOT NULL, -- send, receive, swap, stake, unstake
  symbol VARCHAR(20) NOT NULL,
  amount DECIMAL(20, 8) NOT NULL,
  amount_usd DECIMAL(20, 2),
  from_address VARCHAR(255),
  to_address VARCHAR(255),
  fee_amount DECIMAL(20, 8),
  fee_usd DECIMAL(20, 2),
  status VARCHAR(50) DEFAULT 'pending', -- pending, confirmed, failed, cancelled
  confirmation_count INTEGER DEFAULT 0,
  gas_price DECIMAL(20, 8),
  gas_used DECIMAL(20, 8),
  nonce INTEGER,
  block_number BIGINT,
  block_timestamp TIMESTAMP WITH TIME ZONE,
  network VARCHAR(50), -- mainnet, testnet, polygon, etc
  notes TEXT,
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_transactions_user_id ON public.transactions(user_id);
CREATE INDEX idx_transactions_wallet_id ON public.transactions(wallet_id);
CREATE INDEX idx_transactions_tx_hash ON public.transactions(tx_hash);
CREATE INDEX idx_transactions_status ON public.transactions(status);
CREATE INDEX idx_transactions_created_at ON public.transactions(created_at DESC);
CREATE INDEX idx_transactions_type ON public.transactions(tx_type);

-- ==========================================
-- 6. PRICE HISTORY TABLE
-- ==========================================
CREATE TABLE IF NOT EXISTS public.price_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  symbol VARCHAR(20) NOT NULL,
  price_usd DECIMAL(20, 2) NOT NULL,
  price_change_24h DECIMAL(10, 2),
  market_cap DECIMAL(30, 2),
  volume_24h DECIMAL(30, 2),
  circulating_supply DECIMAL(30, 8),
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  source VARCHAR(50) DEFAULT 'coinbase' -- coinbase, coingecko, binance, etc
);

CREATE INDEX idx_price_history_symbol ON public.price_history(symbol);
CREATE INDEX idx_price_history_timestamp ON public.price_history(timestamp DESC);
CREATE INDEX idx_price_history_symbol_timestamp ON public.price_history(symbol, timestamp DESC);

-- ==========================================
-- 7. WITHDRAWAL REQUESTS TABLE
-- ==========================================
CREATE TABLE IF NOT EXISTS public.withdrawal_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  wallet_id UUID NOT NULL REFERENCES public.wallets(id) ON DELETE CASCADE,
  symbol VARCHAR(20) NOT NULL,
  amount DECIMAL(20, 8) NOT NULL,
  amount_usd DECIMAL(20, 2),
  destination_address VARCHAR(255) NOT NULL,
  network VARCHAR(50) NOT NULL,
  fee_amount DECIMAL(20, 8),
  fee_usd DECIMAL(20, 2),
  status VARCHAR(50) DEFAULT 'pending', -- pending, processing, completed, failed, cancelled
  tx_hash VARCHAR(255),
  rejection_reason TEXT,
  reviewed_by UUID REFERENCES public.users(id),
  reviewed_at TIMESTAMP WITH TIME ZONE,
  email_verification_token VARCHAR(255),
  email_verified_at TIMESTAMP WITH TIME ZONE,
  two_factor_verified_at TIMESTAMP WITH TIME ZONE,
  estimated_completion_at TIMESTAMP WITH TIME ZONE,
  completed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_withdrawals_user_id ON public.withdrawal_requests(user_id);
CREATE INDEX idx_withdrawals_status ON public.withdrawal_requests(status);
CREATE INDEX idx_withdrawals_created_at ON public.withdrawal_requests(created_at DESC);
CREATE INDEX idx_withdrawals_tx_hash ON public.withdrawal_requests(tx_hash);

-- ==========================================
-- 8. PORTFOLIO SNAPSHOTS TABLE
-- ==========================================
CREATE TABLE IF NOT EXISTS public.portfolio_snapshots (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  total_value_usd DECIMAL(20, 2),
  total_value_btc DECIMAL(20, 8),
  total_value_eth DECIMAL(20, 8),
  assets_count INTEGER,
  allocation_data JSONB,
  snapshot_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_portfolio_snapshots_user_id ON public.portfolio_snapshots(user_id);
CREATE INDEX idx_portfolio_snapshots_date ON public.portfolio_snapshots(snapshot_date DESC);

-- ==========================================
-- 9. PRICE ALERTS TABLE
-- ==========================================
CREATE TABLE IF NOT EXISTS public.price_alerts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  symbol VARCHAR(20) NOT NULL,
  alert_type VARCHAR(50) NOT NULL, -- above, below
  target_price DECIMAL(20, 2) NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  triggered BOOLEAN DEFAULT FALSE,
  triggered_at TIMESTAMP WITH TIME ZONE,
  triggered_price DECIMAL(20, 2),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_price_alerts_user_id ON public.price_alerts(user_id);
CREATE INDEX idx_price_alerts_symbol ON public.price_alerts(symbol);
CREATE INDEX idx_price_alerts_is_active ON public.price_alerts(is_active);

-- ==========================================
-- 10. AUDIT LOG TABLE
-- ==========================================
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  action VARCHAR(100) NOT NULL,
  entity_type VARCHAR(50),
  entity_id UUID,
  old_values JSONB,
  new_values JSONB,
  ip_address INET,
  user_agent TEXT,
  status VARCHAR(50) DEFAULT 'success',
  error_message TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_user_id ON public.audit_logs(user_id);
CREATE INDEX idx_audit_logs_created_at ON public.audit_logs(created_at DESC);
CREATE INDEX idx_audit_logs_action ON public.audit_logs(action);

-- ==========================================
-- 11. FUNCTIONS
-- ==========================================

-- Function: Calculate portfolio total value
CREATE OR REPLACE FUNCTION calculate_portfolio_value(p_user_id UUID)
RETURNS TABLE(total_usd DECIMAL, total_btc DECIMAL, total_eth DECIMAL) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COALESCE(SUM(a.balance_usd), 0::DECIMAL) as total_usd,
    COALESCE(SUM(CASE WHEN a.symbol = 'BTC' THEN a.balance ELSE 0 END), 0::DECIMAL) as total_btc,
    COALESCE(SUM(CASE WHEN a.symbol = 'ETH' THEN a.balance ELSE 0 END), 0::DECIMAL) as total_eth
  FROM public.assets a
  WHERE a.user_id = p_user_id AND a.balance > 0;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function: Get 24h change for user
CREATE OR REPLACE FUNCTION get_portfolio_24h_change(p_user_id UUID)
RETURNS TABLE(change_percentage DECIMAL, change_usd DECIMAL) AS $$
DECLARE
  v_current_value DECIMAL;
  v_previous_value DECIMAL;
BEGIN
  SELECT total_usd INTO v_current_value FROM calculate_portfolio_value(p_user_id);
  
  SELECT COALESCE(SUM(allocation_data->>'total_value_usd')::DECIMAL, 0)
  INTO v_previous_value
  FROM public.portfolio_snapshots
  WHERE user_id = p_user_id
  AND snapshot_date > NOW() - INTERVAL '1 day'
  AND snapshot_date < NOW() - INTERVAL '23 hours'
  LIMIT 1;

  RETURN QUERY SELECT
    CASE 
      WHEN v_previous_value > 0 THEN ((v_current_value - v_previous_value) / v_previous_value * 100)::DECIMAL
      ELSE 0::DECIMAL
    END as change_percentage,
    (v_current_value - COALESCE(v_previous_value, v_current_value))::DECIMAL as change_usd;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function: Get transaction summary
CREATE OR REPLACE FUNCTION get_transaction_summary(p_user_id UUID, p_days INTEGER DEFAULT 30)
RETURNS TABLE(tx_type VARCHAR, count BIGINT, total_amount DECIMAL, total_usd DECIMAL) AS $$
BEGIN
  RETURN QUERY
  SELECT
    t.tx_type,
    COUNT(*)::BIGINT,
    SUM(t.amount)::DECIMAL,
    SUM(t.amount_usd)::DECIMAL
  FROM public.transactions t
  WHERE t.user_id = p_user_id
  AND t.created_at >= NOW() - MAKE_INTERVAL(days := p_days)
  GROUP BY t.tx_type;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function: Get user portfolio allocation
CREATE OR REPLACE FUNCTION get_portfolio_allocation(p_user_id UUID)
RETURNS TABLE(symbol VARCHAR, balance DECIMAL, balance_usd DECIMAL, percentage DECIMAL) AS $$
DECLARE
  v_total_usd DECIMAL;
BEGIN
  SELECT total_usd INTO v_total_usd FROM calculate_portfolio_value(p_user_id);
  
  RETURN QUERY
  SELECT
    a.symbol,
    a.balance,
    a.balance_usd,
    CASE
      WHEN v_total_usd > 0 THEN (a.balance_usd / v_total_usd * 100)::DECIMAL
      ELSE 0::DECIMAL
    END as percentage
  FROM public.assets a
  WHERE a.user_id = p_user_id AND a.balance > 0
  ORDER BY a.balance_usd DESC;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function: Update asset prices from price history
CREATE OR REPLACE FUNCTION update_asset_prices()
RETURNS TABLE(updated_count INTEGER) AS $$
DECLARE
  v_count INTEGER := 0;
BEGIN
  WITH latest_prices AS (
    SELECT DISTINCT ON (symbol) 
      symbol,
      price_usd,
      price_change_24h
    FROM public.price_history
    ORDER BY symbol, timestamp DESC
  )
  UPDATE public.assets a
  SET 
    price_usd = lp.price_usd,
    price_change_24h = lp.price_change_24h,
    balance_usd = a.balance * lp.price_usd,
    updated_at = NOW()
  FROM latest_prices lp
  WHERE a.symbol = lp.symbol AND (a.price_usd IS NULL OR a.price_usd != lp.price_usd);
  
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN QUERY SELECT v_count;
END;
$$ LANGUAGE plpgsql;

-- Function: Check and trigger price alerts
CREATE OR REPLACE FUNCTION check_and_trigger_price_alerts()
RETURNS TABLE(triggered_count INTEGER) AS $$
DECLARE
  v_count INTEGER := 0;
BEGIN
  -- Update alerts where target price is reached
  UPDATE public.price_alerts pa
  SET 
    triggered = TRUE,
    triggered_at = NOW(),
    triggered_price = (
      SELECT price_usd FROM public.price_history
      WHERE symbol = pa.symbol
      ORDER BY timestamp DESC
      LIMIT 1
    ),
    is_active = FALSE
  WHERE pa.is_active = TRUE
  AND (
    (pa.alert_type = 'above' AND (
      SELECT price_usd FROM public.price_history
      WHERE symbol = pa.symbol
      ORDER BY timestamp DESC
      LIMIT 1
    ) >= pa.target_price)
    OR
    (pa.alert_type = 'below' AND (
      SELECT price_usd FROM public.price_history
      WHERE symbol = pa.symbol
      ORDER BY timestamp DESC
      LIMIT 1
    ) <= pa.target_price)
  );
  
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN QUERY SELECT v_count;
END;
$$ LANGUAGE plpgsql;

-- Function: Clean up expired sessions
CREATE OR REPLACE FUNCTION cleanup_expired_sessions()
RETURNS TABLE(deleted_count INTEGER) AS $$
DECLARE
  v_count INTEGER := 0;
BEGIN
  DELETE FROM public.sessions
  WHERE expires_at < NOW() OR (is_active = FALSE AND updated_at < NOW() - INTERVAL '7 days');
  
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN QUERY SELECT v_count;
END;
$$ LANGUAGE plpgsql;

-- Function: Log audit event
CREATE OR REPLACE FUNCTION log_audit_event(
  p_user_id UUID,
  p_action VARCHAR,
  p_entity_type VARCHAR,
  p_entity_id UUID,
  p_old_values JSONB,
  p_new_values JSONB,
  p_ip_address INET DEFAULT NULL,
  p_user_agent TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_log_id UUID;
BEGIN
  INSERT INTO public.audit_logs (
    user_id,
    action,
    entity_type,
    entity_id,
    old_values,
    new_values,
    ip_address,
    user_agent
  ) VALUES (
    p_user_id,
    p_action,
    p_entity_type,
    p_entity_id,
    p_old_values,
    p_new_values,
    p_ip_address,
    p_user_agent
  )
  RETURNING id INTO v_log_id;
  
  RETURN v_log_id;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- 12. TRIGGERS
-- ==========================================

-- Trigger: Update users.updated_at
CREATE OR REPLACE FUNCTION update_users_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_update_timestamp
BEFORE UPDATE ON public.users
FOR EACH ROW
EXECUTE FUNCTION update_users_timestamp();

-- Trigger: Update wallets.updated_at
CREATE OR REPLACE FUNCTION update_wallets_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER wallets_update_timestamp
BEFORE UPDATE ON public.wallets
FOR EACH ROW
EXECUTE FUNCTION update_wallets_timestamp();

-- Trigger: Update assets.updated_at
CREATE OR REPLACE FUNCTION update_assets_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER assets_update_timestamp
BEFORE UPDATE ON public.assets
FOR EACH ROW
EXECUTE FUNCTION update_assets_timestamp();

-- Trigger: Update transactions.updated_at
CREATE OR REPLACE FUNCTION update_transactions_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER transactions_update_timestamp
BEFORE UPDATE ON public.transactions
FOR EACH ROW
EXECUTE FUNCTION update_transactions_timestamp();

-- Trigger: Update withdrawal_requests.updated_at
CREATE OR REPLACE FUNCTION update_withdrawal_requests_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER withdrawal_requests_update_timestamp
BEFORE UPDATE ON public.withdrawal_requests
FOR EACH ROW
EXECUTE FUNCTION update_withdrawal_requests_timestamp();

-- Trigger: Update price_alerts.updated_at
CREATE OR REPLACE FUNCTION update_price_alerts_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER price_alerts_update_timestamp
BEFORE UPDATE ON public.price_alerts
FOR EACH ROW
EXECUTE FUNCTION update_price_alerts_timestamp();

-- Trigger: Log wallet connection
CREATE OR REPLACE FUNCTION log_wallet_connection()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM log_audit_event(
    NEW.user_id,
    'WALLET_CONNECTED',
    'wallets',
    NEW.id,
    NULL,
    jsonb_build_object(
      'wallet_address', NEW.wallet_address,
      'wallet_type', NEW.wallet_type
    )
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER wallets_log_connection
AFTER INSERT ON public.wallets
FOR EACH ROW
EXECUTE FUNCTION log_wallet_connection();

-- Trigger: Log wallet disconnection
CREATE OR REPLACE FUNCTION log_wallet_disconnection()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.is_active = TRUE AND NEW.is_active = FALSE THEN
    PERFORM log_audit_event(
      NEW.user_id,
      'WALLET_DISCONNECTED',
      'wallets',
      NEW.id,
      jsonb_build_object('is_active', OLD.is_active),
      jsonb_build_object('is_active', NEW.is_active)
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER wallets_log_disconnection
AFTER UPDATE ON public.wallets
FOR EACH ROW
EXECUTE FUNCTION log_wallet_disconnection();

-- Trigger: Log transaction creation
CREATE OR REPLACE FUNCTION log_transaction_creation()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM log_audit_event(
    NEW.user_id,
    'TRANSACTION_CREATED',
    'transactions',
    NEW.id,
    NULL,
    jsonb_build_object(
      'tx_type', NEW.tx_type,
      'symbol', NEW.symbol,
      'amount', NEW.amount,
      'amount_usd', NEW.amount_usd
    )
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER transactions_log_creation
AFTER INSERT ON public.transactions
FOR EACH ROW
EXECUTE FUNCTION log_transaction_creation();

-- Trigger: Log withdrawal request creation
CREATE OR REPLACE FUNCTION log_withdrawal_request()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM log_audit_event(
    NEW.user_id,
    'WITHDRAWAL_REQUESTED',
    'withdrawal_requests',
    NEW.id,
    NULL,
    jsonb_build_object(
      'symbol', NEW.symbol,
      'amount', NEW.amount,
      'destination_address', NEW.destination_address,
      'network', NEW.network
    )
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER withdrawal_requests_log_creation
AFTER INSERT ON public.withdrawal_requests
FOR EACH ROW
EXECUTE FUNCTION log_withdrawal_request();

-- Trigger: Log withdrawal status changes
CREATE OR REPLACE FUNCTION log_withdrawal_status_change()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.status != NEW.status THEN
    PERFORM log_audit_event(
      NEW.user_id,
      'WITHDRAWAL_STATUS_UPDATED',
      'withdrawal_requests',
      NEW.id,
      jsonb_build_object('status', OLD.status),
      jsonb_build_object('status', NEW.status)
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER withdrawal_requests_log_status
AFTER UPDATE ON public.withdrawal_requests
FOR EACH ROW
EXECUTE FUNCTION log_withdrawal_status_change();

-- Trigger: Validate withdrawal amount
CREATE OR REPLACE FUNCTION validate_withdrawal_amount()
RETURNS TRIGGER AS $$
DECLARE
  v_available_balance DECIMAL;
BEGIN
  SELECT balance INTO v_available_balance
  FROM public.assets
  WHERE user_id = NEW.user_id
  AND symbol = NEW.symbol
  AND wallet_id = NEW.wallet_id;
  
  IF COALESCE(v_available_balance, 0) < NEW.amount THEN
    RAISE EXCEPTION 'Insufficient balance for withdrawal';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER withdrawal_requests_validate
BEFORE INSERT ON public.withdrawal_requests
FOR EACH ROW
EXECUTE FUNCTION validate_withdrawal_amount();

-- Trigger: Create portfolio snapshot on transaction
CREATE OR REPLACE FUNCTION create_portfolio_snapshot_on_transaction()
RETURNS TRIGGER AS $$
DECLARE
  v_total_usd DECIMAL;
  v_total_btc DECIMAL;
  v_total_eth DECIMAL;
BEGIN
  SELECT total_usd, total_btc, total_eth 
  INTO v_total_usd, v_total_btc, v_total_eth
  FROM calculate_portfolio_value(NEW.user_id);
  
  INSERT INTO public.portfolio_snapshots (
    user_id,
    total_value_usd,
    total_value_btc,
    total_value_eth,
    assets_count
  )
  SELECT
    NEW.user_id,
    v_total_usd,
    v_total_btc,
    v_total_eth,
    COUNT(*)
  FROM public.assets
  WHERE user_id = NEW.user_id AND balance > 0;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER transactions_create_snapshot
AFTER INSERT ON public.transactions
FOR EACH ROW
EXECUTE FUNCTION create_portfolio_snapshot_on_transaction();

-- ==========================================
-- 13. ROW LEVEL SECURITY POLICIES
-- ==========================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.withdrawal_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.portfolio_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Policies for users table
CREATE POLICY "Users can view their own profile" ON public.users
  FOR SELECT USING (auth.uid() = auth_id);

CREATE POLICY "Users can update their own profile" ON public.users
  FOR UPDATE USING (auth.uid() = auth_id);

-- Policies for wallets table
CREATE POLICY "Users can view their own wallets" ON public.wallets
  FOR SELECT USING (user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid()));

CREATE POLICY "Users can manage their own wallets" ON public.wallets
  FOR ALL USING (user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid()));

-- Policies for assets table
CREATE POLICY "Users can view their own assets" ON public.assets
  FOR SELECT USING (user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid()));

CREATE POLICY "Users can manage their own assets" ON public.assets
  FOR ALL USING (user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid()));

-- Policies for transactions table
CREATE POLICY "Users can view their own transactions" ON public.transactions
  FOR SELECT USING (user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid()));

-- Policies for withdrawal requests table
CREATE POLICY "Users can view their own withdrawals" ON public.withdrawal_requests
  FOR SELECT USING (user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid()));

CREATE POLICY "Users can create withdrawal requests" ON public.withdrawal_requests
  FOR INSERT WITH CHECK (user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid()));

-- Policies for price alerts table
CREATE POLICY "Users can manage their own price alerts" ON public.price_alerts
  FOR ALL USING (user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid()));

-- Policies for portfolio snapshots table
CREATE POLICY "Users can view their own snapshots" ON public.portfolio_snapshots
  FOR SELECT USING (user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid()));

-- Policies for audit logs table
CREATE POLICY "Users can view their own audit logs" ON public.audit_logs
  FOR SELECT USING (user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid()));

-- ==========================================
-- 14. GRANTS
-- ==========================================

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION calculate_portfolio_value(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_portfolio_24h_change(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_transaction_summary(UUID, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_portfolio_allocation(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION update_asset_prices() TO authenticated;
GRANT EXECUTE ON FUNCTION check_and_trigger_price_alerts() TO authenticated;
GRANT EXECUTE ON FUNCTION cleanup_expired_sessions() TO authenticated;
GRANT EXECUTE ON FUNCTION log_audit_event(UUID, VARCHAR, VARCHAR, UUID, JSONB, JSONB, INET, TEXT) TO authenticated;
