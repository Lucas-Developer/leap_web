class SubscriptionsController < BillingBaseController
  before_filter :require_login
  before_filter :confirm_cancel_subscription, :only => [:destroy]
  before_filter :confirm_self_or_admin, :only => [:index]
  before_filter :confirm_no_pending_active_pastdue_subscription, :only => [:new, :create]
  # for now, admins cannot create or destroy subscriptions for others:
  before_filter :confirm_self, :only => [:new, :create]

  def new
    if current_user.braintree_customer_id
      @client_token = Braintree::ClientToken.generate(customer_id: current_user.braintree_customer_id)
    else
      @client_token = Braintree::ClientToken.generate
    end
    @subscriptions = Braintree::Plan.all
  end

  def create
    @result = Braintree::Subscription.create(
      payment_method_token: braintree_customer.payment_methods.first.token,
      plan_id: params[:plan_id],
    )
    if @result.success?
      flash[:success] = "Congratulations! Your transaction has been successfully!"
    else
      flash[:error] = "Something went wrong while processing your donation. Please try again!"
    end
    redirect_to action: :new, locale: params[:locale]
  end

  def braintree_customer
    if current_user.braintree_customer_id
      Braintree::Customer.find current_user.braintree_customer_id
    else
      customer = Braintree::Customer.create(payment_method_nonce: params[:payment_method_nonce]).customer
      current_user.update_attributes braintree_customer_id: customer.id
      customer
    end
  end

  def confirm
    @result = Braintree::Subscription.sale(
      payment_method_token: params[:payment_method_nonce],
      plans_id: params[:plan_id],
    )
  end

  def _confirm
    make_subscription
    if @result.success?
      flash[:success] = "Congratulations! Your transaction has been successfully!"
    else
      flash[:error] = "Something went wrong while processing your donation. Please try again!"
    end
  redirect_to action: :new, locale: params[:locale]
  end

private

  def make_subscription
    unless current_user.has_payment_info?
      subs_with_user_info
    else
      subs_without_user_info
    end
  end

  def subs_with_user_info
    # don't show link to subscribe if they are already subscribed?
    @result = Braintree::Subscription.sale(
    payment_method_token: params[:payment_method_nonce],
    plans_id: Braintree::Plan.all,
    customer: {
       first_name: params[:first_name],
       last_name: params[:last_name],
       company: params[:company],
       email: current_user.email,
       phone: params[:phone]
       },
    options: {
    store_in_vault: true
    })
    current_user.update_attributes(braintree_customer_id: @result.transaction.customer_details.id) if @result.success?
  end

  def subs_without_user_info
    @result = Braintree::Subscription.sale(
              payment_method_token: params[:payment_method_nonce],
              plans_id: Braintree::Plan.all
    )
  end

  def destroy
    @result = Braintree::Subscription.cancel params[:id]
  end

  def index
    customer = Customer.find_by_user_id(@user.id)
    @subscriptions = customer.subscriptions(nil, false)
  end


  def confirm_cancel_subscription
    access_denied unless view_context.allow_cancel_subscription(@subscription)
  end

  def confirm_no_pending_active_pastdue_subscription
    #@customer = Customer.find_by_user_id(@user.id)
    #if subscription = @customer.subscriptions # will return pending, active or pastdue subscription, if it exists
      #redirect_to user_subscription_path(@user, subscription.id), :notice => 'You already have a subscription'
    #end
  end

  def confirm_self
    @user == current_user
  end

  def confirm_self_or_admin
    access_denied unless confirm_self or admin?
  end

end
