class TabsController < ApplicationController
  def index
    if session[:user_type] == 'Business'
      @business = current_user
    end
      @tabs = current_user.closed_tabs
  end

  def new
    @tab = Tab.new
  end

  def create
    limit_amount = params[:limit_amount]
    limit_cost = params[:limit_cost]

    @business = Business.find_by(username: params[:username].downcase)
    if @business
      open_tabs = @business.open_tabs
      @tab = Tab.find_or_initialize_by(business_id: @business.id, customer_id: current_user.id, transaction_id: nil)
      if open_tabs.include?(@tab)
        @errors = ['It looks like you already have an open tab with this bar. Please navigate to your open tabs to order a drink or close your previous tab']
        render 'new'
      else

        @tab.limit_cost = params[:limit_cost]
        @tab.limit_amount = params[:limit_amount]

        if @tab.save
          redirect_to tab_path(@tab)
        else
          @errors = ['The handle entered does not belong to any bar - please confirm it was entered correctly']
          render 'new'
        end
      end
    else
      @errors = ['The handle entered does not belong to any bar - please confirm it was entered correctly']
      render 'new'
    end
  end

  def show
    @tab = Tab.find(params[:id])
    @item = Item.new
    render 'show'
  end

  def checkout
    @tab = Tab.find(params[:id])
    @client_token = CreditCardService.new(customer: @tab.customer).generate_token(vault_id: @tab.customer.vault_id)
    render 'checkout'
  end

  def destroy
    @tab = Tab.find(params[:id])
    customer = Customer.find(@tab.customer_id)
    @tab.destroy!
    redirect_to customer_path(customer)
  end

  def close
    @tab = Tab.find(params[:id])
    @customer = @tab.customer
    sub_total = @tab.total_price
    tip_percentage = params[:close][:tip].to_i
    total = sub_total * tip_percentage / 100 + sub_total
    result = CreditCardService.new(customer: @tab.customer).create_transaction(total)
    @tab.transaction_id = result.transaction.id
    @tab.tip = sub_total * tip_percentage / 100
    if @tab.save
      if session[:user_type] == 'Customer'
        @transaction = true
        @recent_tabs = @customer.tabs.order("updated_at DESC").limit(3)
        @open_tabs = @customer.tabs.where(transaction_id: nil)
        render '/customers/show'
      else
        redirect_to @tab.business
      end
    else
      if session[:user_type] == 'Customer'
        @transaction = false
        render 'show'
      else
        redirect_to @tab.business
      end
    end
  end
end
