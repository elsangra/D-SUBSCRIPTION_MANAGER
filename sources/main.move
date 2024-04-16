#[allow(lint(self_transfer))]
module platform::subscription {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::coin::{Self, Coin};
    use sui::table::{Table, Self};
    use sui::transfer;
    use sui::clock::{Self, Clock};
    use std::string::{String};
    use std::vector;

    /// Error Constants ///
    const ENoSubscription: u64 = 0; // No active subscription for the user
    const EInsufficientFunds: u64 = 1; // Insufficient funds to subscribe or renew
    const EInvalidTransaction: u64 = 2; // Invalid transaction type
    const ESubscriptionExists: u64 = 3; // User already has an active subscription

    // Type that stores transaction data for a subscription:
    struct SubscriptionTransaction has store, copy, drop {
        transaction_type: String,
        amount: u64,
        // In a subscription model, we don't need 'to' and 'from' fields
    }

    // Type that stores user account data:
    struct UserAccount<phantom COIN> has key, store {
        id: UID,
        create_date: u64,
        last_subscription_date: u64,
        subscription_valid_until: u64,
        subscription_fee: Coin<COIN>,
        user_address: address,
        subscription_transactions: vector<SubscriptionTransaction>
    }

    // Type that represents the platform's subscription system:
    struct SubscriptionPlatform<phantom COIN> has key, store {
        id: UID,
        user_accounts: Table<address, UserAccount<COIN>>,
        platform_address: address
    }

    /// Create a new subscription platform.
    public fun create_platform<COIN>(ctx: &mut TxContext) {
        let id = object::new(ctx);
        let user_accounts = table::new<address, UserAccount<COIN>>(ctx);
        transfer::share_object(SubscriptionPlatform<COIN> {
            id,
            user_accounts,
            platform_address: tx_context::sender(ctx)
        })
    }

    // Subscribe a user to the platform.
    public fun subscribe<COIN>(
        platform: &mut SubscriptionPlatform<COIN>,
        clock: &Clock,
        subscription_fee: Coin<COIN>,
        ctx: &mut TxContext
    ) {
        // Check if user already has an active subscription
        assert!(!table::contains<address, UserAccount<COIN>>(&platform.user_accounts, tx_context::sender(ctx)), ESubscriptionExists);
        let user_account = UserAccount {
            id: object::new(ctx),
            create_date: clock::timestamp_ms(clock),
            last_subscription_date: clock::timestamp_ms(clock),
            subscription_valid_until: clock::timestamp_ms(clock) + 365 * 24 * 60 * 60 * 1000, // 1 year subscription
            subscription_fee: subscription_fee,
            user_address: tx_context::sender(ctx),
            subscription_transactions: vector::empty<SubscriptionTransaction>()
        };
        // Save user account to the platform
        table::add(&mut platform.user_accounts, tx_context::sender(ctx), user_account);
    }

    // Renew a user's subscription on the platform.
    public fun renew_subscription<COIN>(
        platform: &mut SubscriptionPlatform<COIN>,
        ctx: &mut TxContext
    ) {
        assert!(table::contains<address, UserAccount<COIN>>(&platform.user_accounts, tx_context::sender(ctx)), ENoSubscription);
        let user_account = table::borrow_mut<address, UserAccount<COIN>>(&mut platform.user_accounts, tx_context::sender(ctx));
        let subscription_fee = &mut user_account.subscription_fee;
        assert!(coin::value(subscription_fee) >= 0, EInsufficientFunds);
        user_account.last_subscription_date = clock::timestamp_ms(ctx.clock());
        user_account.subscription_valid_until = user_account.last_subscription_date + 365 * 24 * 60 * 60 * 1000; // Renew for 1 year
    }

    // Unsubscribe a user from the platform.
    public fun unsubscribe<COIN>(
        platform: &mut SubscriptionPlatform<COIN>,
        ctx: &mut TxContext
    ) {
        assert!(table::contains<address, UserAccount<COIN>>(&platform.user_accounts, tx_context::sender(ctx)), ENoSubscription);
        let user_account = table::remove<address, UserAccount<COIN>>(&mut platform.user_accounts, tx_context::sender(ctx));
        // Transfer any remaining subscription fee back to the user
        transfer::public_transfer(user_account.subscription_fee, tx_context::sender(ctx));
        // Destroy the user account
        object::delete(user_account.id);
    }

    // Accessor functions

    public fun user_create_date<COIN>(platform: &SubscriptionPlatform<COIN>, ctx: &mut TxContext): u64 {
        assert!(table::contains<address, UserAccount<COIN>>(&platform.user_accounts, tx_context::sender(ctx)), ENoSubscription);
        let user_account = table::borrow<address, UserAccount<COIN>>(&platform.user_accounts, tx_context::sender(ctx));
        user_account.create_date
    }

    public fun user_last_subscription_date<COIN>(platform: &SubscriptionPlatform<COIN>, ctx: &mut TxContext): u64 {
        assert!(table::contains<address, UserAccount<COIN>>(&platform.user_accounts, tx_context::sender(ctx)), ENoSubscription);
        let user_account = table::borrow<address, UserAccount<COIN>>(&platform.user_accounts, tx_context::sender(ctx));
        user_account.last_subscription_date
    }

    public fun user_subscription_valid_until<COIN>(platform: &SubscriptionPlatform<COIN>, ctx: &mut TxContext): u64 {
        assert!(table::contains<address, UserAccount<COIN>>(&platform.user_accounts, tx_context::sender(ctx)), ENoSubscription);
        let user_account = table::borrow<address, UserAccount<COIN>>(&platform.user_accounts, tx_context::sender(ctx));
        user_account.subscription_valid_until
    }

    public fun user_subscription_fee<COIN>(platform: &SubscriptionPlatform<COIN>, ctx: &mut TxContext): u64 {
        assert!(table::contains<address, UserAccount<COIN>>(&platform.user_accounts, tx_context::sender(ctx)), ENoSubscription);
        let user_account = table::borrow<address, UserAccount<COIN>>(&platform.user_accounts, tx_context::sender(ctx));
        coin::value(&user_account.subscription_fee)
    }
}
