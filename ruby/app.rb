require 'date'
require 'set'
require 'json'

# Core facet module that all facets include
module Facet
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def facet_type
      @facet_type ||= name.downcase.gsub(/facet$/, '')
    end

    def facet_type=(type)
      @facet_type = type
    end
  end

  def facet_type
    self.class.facet_type
  end
end

# Main faceted object implementation
class FacetedObject
  def initialize(core_object)
    @core_object = core_object
    @facets = {}
    @method_cache = {}
    
    # Enable method delegation
    extend_with_facet_methods
  end

  def attach_facet(facet_instance)
    facet_type = facet_instance.facet_type
    
    if @facets.key?(facet_type)
      raise ArgumentError, "Facet '#{facet_type}' already attached"
    end

    @facets[facet_type] = facet_instance
    
    # Add facet methods to this instance
    add_facet_methods(facet_instance)
    
    # Call initialization hook if facet defines it
    facet_instance.on_attached(self) if facet_instance.respond_to?(:on_attached)
    
    facet_instance
  end

  def detach_facet(facet_type_or_class)
    facet_type = case facet_type_or_class
                 when String
                   facet_type_or_class
                 when Class
                   facet_type_or_class.facet_type
                 else
                   facet_type_or_class.facet_type
                 end

    facet = @facets.delete(facet_type)
    
    if facet
      # Remove facet methods
      remove_facet_methods(facet)
      
      # Call cleanup hook if facet defines it
      facet.on_detached(self) if facet.respond_to?(:on_detached)
    end
    
    facet
  end

  def get_facet(facet_type_or_class)
    facet_type = case facet_type_or_class
                 when String
                   facet_type_or_class
                 when Class
                   facet_type_or_class.facet_type
                 else
                   facet_type_or_class.facet_type
                 end

    @facets[facet_type]
  end

  def has_facet?(facet_type_or_class)
    !get_facet(facet_type_or_class).nil?
  end

  def facet_types
    @facets.keys
  end

  def core_object
    @core_object
  end

  def with_facet(facet_type_or_class)
    facet = get_facet(facet_type_or_class)
    raise ArgumentError, "Facet not found: #{facet_type_or_class}" unless facet
    
    yield(facet)
  end

  # Require specific facets for an operation
  def requires_facets(*facet_types, &block)
    missing_facets = facet_types.select { |type| !has_facet?(type) }
    
    unless missing_facets.empty?
      raise ArgumentError, "Missing required facets: #{missing_facets.join(', ')}"
    end
    
    block.call(self) if block_given?
  end

  private

  def extend_with_facet_methods
    # Add method_missing to handle facet method calls
    singleton_class.class_eval do
      define_method :method_missing do |method_name, *args, &block|
        # Try to find the method in attached facets
        @facets.values.each do |facet|
          if facet.respond_to?(method_name)
            return facet.send(method_name, *args, &block)
          end
        end
        
        # Try the core object
        if @core_object.respond_to?(method_name)
          return @core_object.send(method_name, *args, &block)
        end
        
        super(method_name, *args, &block)
      end

      define_method :respond_to_missing? do |method_name, include_private = false|
        @facets.values.any? { |facet| facet.respond_to?(method_name, include_private) } ||
          @core_object.respond_to?(method_name, include_private) ||
          super(method_name, include_private)
      end
    end
  end

  def add_facet_methods(facet)
    facet.public_methods(false).each do |method_name|
      next if method_name == :facet_type

      # Create a delegating method for each public method of the facet
      singleton_class.class_eval do
        define_method("#{facet.facet_type}_#{method_name}") do |*args, &block|
          facet.send(method_name, *args, &block)
        end
      end
    end
  end

  def remove_facet_methods(facet)
    facet.public_methods(false).each do |method_name|
      method_to_remove = "#{facet.facet_type}_#{method_name}"
      
      if respond_to?(method_to_remove)
        singleton_class.class_eval do
          remove_method(method_to_remove) if method_defined?(method_to_remove)
        end
      end
    end
  end
end

# Example domain class
class Employee
  attr_accessor :name, :id, :department, :email, :hire_date

  def initialize(name, id, department, email, hire_date = Date.today)
    @name = name
    @id = id
    @department = department
    @email = email
    @hire_date = hire_date
  end

  def years_of_service
    ((Date.today - @hire_date) / 365.25).to_i
  end

  def to_h
    {
      name: @name,
      id: @id,
      department: @department,
      email: @email,
      hire_date: @hire_date,
      years_of_service: years_of_service
    }
  end
end

# Account facet for financial operations
class AccountFacet
  include Facet
  
  attr_reader :account_number, :balance

  def initialize(account_number, initial_balance = 0)
    @account_number = account_number
    @balance = initial_balance.to_f
    @transactions = []
  end

  def deposit(amount)
    raise ArgumentError, "Amount must be positive" unless amount > 0
    
    @balance += amount
    log_transaction('deposit', amount)
    @balance
  end

  def withdraw(amount)
    raise ArgumentError, "Amount must be positive" unless amount > 0
    raise ArgumentError, "Insufficient funds" if amount > @balance
    
    @balance -= amount
    log_transaction('withdrawal', amount)
    @balance
  end

  def transfer_to(target_account_number, amount)
    raise ArgumentError, "Cannot transfer to same account" if target_account_number == @account_number
    
    withdraw(amount)
    log_transaction('transfer_out', amount, target_account_number)
    amount
  end

  def receive_transfer(from_account_number, amount)
    deposit(amount)
    log_transaction('transfer_in', amount, from_account_number)
    @balance
  end

  def transaction_history(limit = nil)
    limit ? @transactions.last(limit) : @transactions.dup
  end

  def monthly_summary(year, month)
    start_date = Date.new(year, month, 1)
    end_date = start_date.next_month - 1
    
    monthly_transactions = @transactions.select do |tx|
      tx[:timestamp].to_date.between?(start_date, end_date)
    end

    {
      period: "#{year}-#{month.to_s.rjust(2, '0')}",
      transactions: monthly_transactions,
      total_deposits: monthly_transactions.select { |tx| tx[:type] == 'deposit' }.sum { |tx| tx[:amount] },
      total_withdrawals: monthly_transactions.select { |tx| tx[:type] == 'withdrawal' }.sum { |tx| tx[:amount] }
    }
  end

  private

  def log_transaction(type, amount, reference = nil)
    @transactions << {
      type: type,
      amount: amount,
      balance_after: @balance,
      timestamp: Time.now,
      reference: reference
    }
  end
end

# Performance tracking facet
class PerformanceFacet
  include Facet
  
  def initialize
    @metrics = {}
    @goals = {}
    @reviews = []
  end

  def set_metric(name, value, period = Date.today)
    @metrics[name] ||= []
    @metrics[name] << { value: value, period: period, timestamp: Time.now }
  end

  def get_metric(name, period = nil)
    return nil unless @metrics[name]
    
    if period
      @metrics[name].find { |m| m[:period] == period }&.fetch(:value)
    else
      @metrics[name].last&.fetch(:value)
    end
  end

  def set_goal(name, target_value, deadline)
    @goals[name] = { target: target_value, deadline: deadline, set_on: Date.today }
  end

  def goal_progress(name)
    goal = @goals[name]
    return nil unless goal
    
    current_value = get_metric(name)
    return nil unless current_value
    
    progress = (current_value.to_f / goal[:target]) * 100
    {
      goal: goal,
      current_value: current_value,
      progress_percentage: progress.round(2),
      days_remaining: (goal[:deadline] - Date.today).to_i
    }
  end

  def add_review(rating, comments, reviewer, review_date = Date.today)
    @reviews << {
      rating: rating,
      comments: comments,
      reviewer: reviewer,
      review_date: review_date,
      timestamp: Time.now
    }
  end

  def average_rating(last_n_reviews = nil)
    reviews_to_consider = last_n_reviews ? @reviews.last(last_n_reviews) : @reviews
    return 0 if reviews_to_consider.empty?
    
    total = reviews_to_consider.sum { |review| review[:rating] }
    (total.to_f / reviews_to_consider.size).round(2)
  end

  def performance_summary
    {
      metrics: @metrics.transform_values { |values| values.last },
      goals: @goals.transform_values { |goal| goal_progress(@goals.key(goal)) },
      recent_reviews: @reviews.last(3),
      average_rating: average_rating,
      total_reviews: @reviews.size
    }
  end
end

# Security facet for access control and audit
class SecurityFacet
  include Facet
  
  def initialize(security_level = 'basic')
    @security_level = security_level
    @access_log = []
    @failed_attempts = []
    @permissions = Set.new
    @active_sessions = {}
    
    setup_default_permissions
  end

  def authenticate(credentials)
    # Simulate authentication
    success = credentials[:password] == 'secret123'
    
    log_access_attempt(credentials[:user_id], success)
    
    if success
      session_id = generate_session_id
      @active_sessions[session_id] = {
        user_id: credentials[:user_id],
        start_time: Time.now,
        last_activity: Time.now
      }
      session_id
    else
      nil
    end
  end

  def validate_session(session_id)
    session = @active_sessions[session_id]
    return false unless session
    
    # Check session timeout (30 minutes)
    if Time.now - session[:last_activity] > 1800
      @active_sessions.delete(session_id)
      return false
    end
    
    session[:last_activity] = Time.now
    true
  end

  def logout(session_id)
    @active_sessions.delete(session_id)
  end

  def grant_permission(permission)
    @permissions.add(permission)
  end

  def revoke_permission(permission)
    @permissions.delete(permission)
  end

  def has_permission?(permission)
    @permissions.include?(permission) || @permissions.include?('admin')
  end

  def require_permission(permission)
    unless has_permission?(permission)
      raise SecurityError, "Access denied: missing permission '#{permission}'"
    end
  end

  def security_report
    {
      security_level: @security_level,
      permissions: @permissions.to_a,
      active_sessions: @active_sessions.size,
      recent_access_attempts: @access_log.last(10),
      failed_attempts_today: failed_attempts_today.size,
      total_access_attempts: @access_log.size
    }
  end

  private

  def setup_default_permissions
    case @security_level
    when 'admin'
      @permissions.merge(['read', 'write', 'delete', 'admin', 'financial'])
    when 'manager'
      @permissions.merge(['read', 'write', 'financial'])
    when 'employee'
      @permissions.merge(['read'])
    end
  end

  def log_access_attempt(user_id, success)
    attempt = {
      user_id: user_id,
      success: success,
      timestamp: Time.now,
      ip_address: '127.0.0.1' # Would be actual IP in real implementation
    }
    
    @access_log << attempt
    @failed_attempts << attempt unless success
  end

  def failed_attempts_today
    today = Date.today
    @failed_attempts.select { |attempt| attempt[:timestamp].to_date == today }
  end

  def generate_session_id
    "session_#{Time.now.to_i}_#{rand(10000)}"
  end
end

# Notification facet for messaging and alerts
class NotificationFacet
  include Facet
  
  def initialize
    @subscribers = Hash.new { |hash, key| hash[key] = [] }
    @message_history = []
    @preferences = {
      email: true,
      sms: false,
      push: true,
      frequency: 'immediate'
    }
  end

  def subscribe(event_type, &handler)
    @subscribers[event_type] << handler
  end

  def unsubscribe(event_type, handler)
    @subscribers[event_type].delete(handler)
  end

  def notify(event_type, data = {})
    timestamp = Time.now
    message = {
      event_type: event_type,
      data: data,
      timestamp: timestamp
    }
    
    @message_history << message
    
    # Deliver to subscribers
    @subscribers[event_type].each do |handler|
      begin
        handler.call(message)
      rescue => e
        puts "Notification handler error: #{e.message}"
      end
    end
    
    # Simulate different delivery channels based on preferences
    deliver_message(message) if should_deliver?(event_type)
  end

  def set_preference(channel, enabled)
    @preferences[channel] = enabled
  end

  def set_frequency(frequency)
    raise ArgumentError, "Invalid frequency" unless %w[immediate hourly daily].include?(frequency)
    @preferences[:frequency] = frequency
  end

  def message_history(limit = nil)
    limit ? @message_history.last(limit) : @message_history.dup
  end

  def unread_count
    # In a real implementation, this would track read status
    @message_history.count { |msg| msg[:timestamp] > Time.now - 3600 } # Last hour
  end

  private

  def should_deliver?(event_type)
    # Simple delivery logic based on preferences
    case @preferences[:frequency]
    when 'immediate'
      true
    when 'hourly'
      @message_history.select { |msg| msg[:timestamp] > Time.now - 3600 }.size <= 1
    when 'daily'
      @message_history.select { |msg| msg[:timestamp] > Time.now - 86400 }.size <= 1
    else
      true
    end
  end

  def deliver_message(message)
    puts "📧 Email: #{message[:event_type]} - #{message[:data]}" if @preferences[:email]
    puts "📱 Push: #{message[:event_type]} - #{message[:data]}" if @preferences[:push]
    puts "📞 SMS: #{message[:event_type]} - #{message[:data]}" if @preferences[:sms]
  end
end

# Service class for coordinated operations
class EmployeeService
  def self.create_employee(name, id, department, email, capabilities = {})
    employee = Employee.new(name, id, department, email)
    faceted_employee = FacetedObject.new(employee)
    
    # Attach facets based on capabilities
    if capabilities[:account]
      account_facet = AccountFacet.new(capabilities[:account][:number], capabilities[:account][:balance])
      faceted_employee.attach_facet(account_facet)
    end
    
    if capabilities[:security]
      security_facet = SecurityFacet.new(capabilities[:security][:level])
      capabilities[:security][:permissions]&.each { |perm| security_facet.grant_permission(perm) }
      faceted_employee.attach_facet(security_facet)
    end
    
    if capabilities[:performance_tracking]
      faceted_employee.attach_facet(PerformanceFacet.new)
    end
    
    if capabilities[:notifications]
      notification_facet = NotificationFacet.new
      
      # Set up default notification handlers
      notification_facet.subscribe('financial_transaction') do |message|
        puts "🏦 Financial Alert: #{message[:data][:type]} of $#{message[:data][:amount]}"
      end
      
      notification_facet.subscribe('performance_update') do |message|
        puts "📊 Performance Update: #{message[:data][:metric]} = #{message[:data][:value]}"
      end
      
      faceted_employee.attach_facet(notification_facet)
    end
    
    faceted_employee
  end

  def self.perform_secure_transaction(employee_obj, transaction_type, amount)
    employee_obj.requires_facets('security', 'account') do |obj|
      # Authenticate and check permissions
      security = obj.get_facet('security')
      security.require_permission('financial')
      
      # Perform transaction
      account = obj.get_facet('account')
      result = case transaction_type
               when 'deposit'
                 account.deposit(amount)
               when 'withdraw'
                 account.withdraw(amount)
               else
                 raise ArgumentError, "Unknown transaction type: #{transaction_type}"
               end
      
      # Send notification if available
      if obj.has_facet?('notification')
        notification = obj.get_facet('notification')
        notification.notify('financial_transaction', {
          type: transaction_type,
          amount: amount,
          new_balance: result,
          employee: obj.core_object.name
        })
      end
      
      result
    end
  end

  def self.update_performance(employee_obj, metric_name, value)
    employee_obj.with_facet('performance') do |performance|
      performance.set_metric(metric_name, value)
      
      # Notify if notification facet is available
      if employee_obj.has_facet?('notification')
        notification = employee_obj.get_facet('notification')
        notification.notify('performance_update', {
          metric: metric_name,
          value: value,
          employee: employee_obj.core_object.name
        })
      end
    end
  end

  def self.comprehensive_report(employee_obj)
    employee = employee_obj.core_object
    
    report = {
      employee_info: employee.to_h,
      attached_facets: employee_obj.facet_types,
      timestamp: Time.now
    }
    
    # Add facet-specific information
    if employee_obj.has_facet?('account')
      account = employee_obj.get_facet('account')
      report[:financial] = {
        account_number: account.account_number,
        balance: account.balance,
        recent_transactions: account.transaction_history(5)
      }
    end
    
    if employee_obj.has_facet?('performance')
      performance = employee_obj.get_facet('performance')
      report[:performance] = performance.performance_summary
    end
    
    if employee_obj.has_facet?('security')
      security = employee_obj.get_facet('security')
      report[:security] = security.security_report
    end
    
    if employee_obj.has_facet?('notification')
      notification = employee_obj.get_facet('notification')
      report[:notifications] = {
        unread_count: notification.unread_count,
        recent_messages: notification.message_history(3)
      }
    end
    
    report
  end
end

# Usage demonstration
def demonstrate_facet_system
  puts "=== Dynamic Facet Composition Demo ==="
  
  # Create employee with various capabilities
  employee_obj = EmployeeService.create_employee(
    'Sarah Connor', 'EMP003', 'Engineering', 'sarah.connor@company.com',
    {
      account: { number: 'ACC003', balance: 1000 },
      security: { level: 'manager', permissions: ['read', 'write', 'financial'] },
      performance_tracking: true,
      notifications: true
    }
  )
  
  puts "\n--- Initial Employee State ---"
  puts "Attached facets: #{employee_obj.facet_types.join(', ')}"
  
  # Demonstrate financial operations
  puts "\n--- Financial Operations ---"
  begin
    # First authenticate (in a real system)
    security = employee_obj.get_facet('security')
    session_id = security.authenticate(user_id: 'sarah', password: 'secret123')
    puts "Authentication successful: #{session_id}"
    
    # Perform transactions
    new_balance = EmployeeService.perform_secure_transaction(employee_obj, 'deposit', 500)
    puts "Deposit completed. New balance: $#{new_balance}"
    
    new_balance = EmployeeService.perform_secure_transaction(employee_obj, 'withdraw', 200)
    puts "Withdrawal completed. New balance: $#{new_balance}"
    
  rescue => e
    puts "Transaction failed: #{e.message}"
  end
  
  # Demonstrate performance tracking
  puts "\n--- Performance Tracking ---"
  EmployeeService.update_performance(employee_obj, 'projects_completed', 5)
  EmployeeService.update_performance(employee_obj, 'customer_satisfaction', 4.5)
  
  performance = employee_obj.get_facet('performance')
  performance.set_goal('projects_completed', 10, Date.today + 90)
  
  puts "Goal progress: #{performance.goal_progress('projects_completed')}"
  
  # Generate comprehensive report
  puts "\n--- Comprehensive Employee Report ---"
  report = EmployeeService.comprehensive_report(employee_obj)
  puts JSON.pretty_generate(report)
  
  # Demonstrate dynamic facet management
  puts "\n--- Dynamic Facet Management ---"
  puts "Before detachment: #{employee_obj.facet_types.join(', ')}"
  
  # Detach performance facet
  employee_obj.detach_facet('performance')
  puts "After detaching performance: #{employee_obj.facet_types.join(', ')}"
  
  # Try to use detached facet (should fail gracefully)
  begin
    EmployeeService.update_performance(employee_obj, 'test_metric', 1)
  rescue => e
    puts "Expected error when using detached facet: #{e.message}"
  end
end

# Run the demonstration
demonstrate_facet_system
