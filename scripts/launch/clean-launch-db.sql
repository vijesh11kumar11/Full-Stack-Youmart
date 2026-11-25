-- Removes development/test data from a COPY of the database before it goes to production.
-- Run against the launch copy only (never youmart_dev):
--   docker exec -i docker-postgres-1 psql -U youmart_dev -d youmart_launch -v ON_ERROR_STOP=1 < scripts/launch/clean-launch-db.sql
-- Keeps: categories, the default "YouMart" seller and its real products (images, SKUs, stock),
-- marketplace settings, admin roles/permissions, migrations.
BEGIN;

-- 1. Products to remove -------------------------------------------------------------------
CREATE TEMP TABLE drop_product ON COMMIT DROP AS
SELECT DISTINCT p.id
FROM catalog.product p
LEFT JOIN catalog.product_image i ON i.product_id = p.id
LEFT JOIN sellers.seller s ON s.id = p.seller_id
WHERE i.url LIKE '%cdn.dummyjson.com%'            -- early demo import with placeholder photos
   OR i.url NOT LIKE '%://%'                      -- dev seed products (dev/*.jpg, files that don't exist)
   OR i.url LIKE '%localhost%'                    -- image only reachable on the dev PC
   OR i.url LIKE '%m.media-amazon.com%'           -- hot-linked Amazon photos (duplicate product)
   OR s.is_default_seller IS NOT TRUE;            -- products of test sellers

CREATE TEMP TABLE drop_sku ON COMMIT DROP AS
SELECT id FROM catalog.sku WHERE product_id IN (SELECT id FROM drop_product);

SELECT (SELECT count(*) FROM drop_product) AS products_removed, (SELECT count(*) FROM drop_sku) AS skus_removed;

DELETE FROM inventory.reservation       WHERE sku_id     IN (SELECT id FROM drop_sku);
DELETE FROM inventory.stock_level       WHERE sku_id     IN (SELECT id FROM drop_sku);
DELETE FROM catalog.product_image       WHERE product_id IN (SELECT id FROM drop_product);
DELETE FROM catalog.product_extra_category WHERE product_id IN (SELECT id FROM drop_product);
DELETE FROM catalog.sku                 WHERE id         IN (SELECT id FROM drop_sku);
DELETE FROM catalog.product             WHERE id         IN (SELECT id FROM drop_product);

-- 2. Everything created by test users / test orders ----------------------------------------
TRUNCATE
  orders.order_status_history, orders.order_cancel_request, orders.order_notify_preference,
  orders.order_item, orders."order", orders.referral_reward,
  payments.refund, payments.payment_webhook_event, payments.payment,
  payments.wallet_transaction, payments.wallet_hold, payments.wallet_topup, payments.wallet,
  invoices.invoice_line, invoices.invoice, invoices.invoice_counter,
  logistics.shipment, tracking.tracking_event, returns.return_request,
  settlements.settlement_line, settlements.settlement,
  inventory.reservation,
  cart.cart_item, cart.cart, cart.wishlist_item, catalog.recently_viewed,
  promotions.coupon_redemption, promotions.coupon,
  reviews.review,
  notifications.buy_reminder, notifications.checkout_nudge, notifications.finder_query,
  notifications.inbox_message, notifications.notification_log, notifications.product_request,
  notifications.support_message, notifications.support_ticket,
  sellers.ad_media, sellers.ad_campaign, sellers.seller_application,
  addresses.address,
  auth.refresh_token, auth.oauth_account, auth.otp_challenge, auth.qr_login_session, auth."user";

-- Stock held by the deleted test orders goes back to normal.
UPDATE inventory.stock_level SET reserved = 0 WHERE reserved <> 0;

-- 3. Test sellers (keep only the default YouMart seller) -----------------------------------
DELETE FROM sellers.seller_kyc WHERE seller_id IN (SELECT id FROM sellers.seller WHERE is_default_seller IS NOT TRUE);
DELETE FROM sellers.seller     WHERE is_default_seller IS NOT TRUE;
UPDATE sellers.seller SET owner_user_id = NULL WHERE owner_user_id IS NOT NULL;

-- 4. Development admin logins (known dev passwords). The production admin is created
--    afterwards with scripts/launch/create-admin.ps1 (you type the password yourself).
DELETE FROM admin.admin;

-- 5. Report --------------------------------------------------------------------------------
SELECT 'products' AS what, count(*) FROM catalog.product
UNION ALL SELECT 'active products', count(*) FROM catalog.product WHERE status = 'ACTIVE'
UNION ALL SELECT 'images', count(*) FROM catalog.product_image
UNION ALL SELECT 'skus', count(*) FROM catalog.sku
UNION ALL SELECT 'sellers', count(*) FROM sellers.seller
UNION ALL SELECT 'users', count(*) FROM auth."user"
UNION ALL SELECT 'orders', count(*) FROM orders."order"
UNION ALL SELECT 'admins', count(*) FROM admin.admin
UNION ALL SELECT 'non-R2 images', count(*) FROM catalog.product_image WHERE url NOT LIKE '%r2.dev%';

COMMIT;
