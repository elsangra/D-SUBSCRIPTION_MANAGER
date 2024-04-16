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
        timestamp: u64,
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
    struct SubscriptionPlatform<phantom COIN> has key {
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
            last_subscription_date: 0,
            subscription_valid_until: 0,
            subscription_fee,
            user_address: tx_context::sender(ctx),
            subscription_transactions: vector::empty<SubscriptionTransaction>()
        };
        // Save user account to the platform
        table::add(&mut platform.user_accounts, tx_context::sender(ctx), user_account);
    }

    // Renew a user's subscription on the platform.
    public fun renew_subscription<COIN>(
        platform: &mut SubscriptionPlatform<COIN>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(table::contains<address, UserAccount<COIN>>(&platform.user_accounts, tx_context::sender(ctx)), ENoSubscription);
        let user_account = table::borrow_mut<address, UserAccount<COIN>>(&mut platform.user_accounts, tx_context::sender(ctx));
        assert!(coin::value(&user_account.subscription_fee) >= 0, EInsufficientFunds);
        
        // Update subscription details
        user_account.last_subscription_date = clock::timestamp_ms(clock);
        // Logic to calculate new subscription validity based on renewal
        // For example, if we're adding 30 days to the current validity:
        user_account.subscription_valid_until += 30 * 24 * 60 * 60 * 1000; // Adding 30 days in milliseconds
        
        // Log subscription renewal transaction
        let renewal_transaction = SubscriptionTransaction {
            transaction_type: String::from("Renewal"),
            amount: coin::value(&user_account.subscription_fee),
            timestamp: clock::timestamp_ms(clock),
        };
        vector::push(&mut user_account.subscription_transactions, renewal_transaction);
    }

    // Unsubscribe a user from the platform.
    public fun unsubscribe<COIN>(
        platform: &mut SubscriptionPlatform<COIN>,
        ctx: &mut TxContext
    ) {
        assert!(table::contains<address, UserAccount<COIN>>(&platform.user_accounts, tx_context::sender(ctx)), ENoSubscription);
        // Remove user account from the platform
        table::remove(&mut platform.user_accounts, tx_context::sender(ctx));
    }

    // Accessor functions

    public fun user_create_date<COIN>(self: &SubscriptionPlatform<COIN>, ctx: &mut TxContext): u64 {
        assert!(table::contains<address, UserAccount<COIN>>(&self.user_accounts, tx_context::sender(ctx)), ENoSubscription);
        let user_account = table::borrow<address, UserAccount<COIN>>(&self.user_accounts, tx_context::sender(ctx));
        user_account.create_date
    }

    // Implement other accessor functions as needed...

    // Example accessor function for fetching user's subscription fee
    public fun user_subscription_fee<COIN>(self: &SubscriptionPlatform<COIN>, ctx: &mut TxContext): u64 {
        assert!(table::contains<address, UserAccount<COIN>>(&self.user_accounts, tx_context::sender(ctx)), ENoSubscription);
        let user_account = table::borrow<address, UserAccount<COIN>>(&self.user_accounts, tx_context::sender(ctx));
        coin::value(&user_account.subscription_fee)
    }


    // Function to check if user's subscription is valid
    public fun is_subscription_valid<COIN>(self: &SubscriptionPlatform<COIN>, ctx: &mut TxContext, clock: &Clock) -> bool {
        if let Some(user_account) = table::get::<address, UserAccount<COIN>>(&self.user_accounts, tx_context::sender(ctx)) {
            return user_account.subscription_valid_until >= clock::timestamp_ms(clock);
        }
        false
    }

    // Function to update user's subscription fee
    public fun update_subscription_fee<COIN>(
        platform: &mut SubscriptionPlatform<COIN>,
        new_fee: Coin<COIN>,
        ctx: &mut TxContext
    ) {
        assert!(table::contains<address, UserAccount<COIN>>(&platform.user_accounts, tx_context::sender(ctx)), ENoSubscription);
        let mut user_account = table::get_mut::<address, UserAccount<COIN>>(&mut platform.user_accounts, tx_context::sender(ctx)).unwrap();
        user_account.subscription_fee = new_fee;
    }

}


