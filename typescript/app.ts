// Base interfaces for the facet system

// Base interfaces for the facet system
interface Facet {
  readonly facetType: string;
}

interface FacetConstructor<T extends Facet> {
  new(...args: any[]): T;
  readonly facetType: string;
}

// Core faceted object implementation
class FacetedObject<TCore = any> {
  private facets: Map<string, Facet> = new Map();
  private core: TCore;

  constructor(core: TCore) {
    this.core = core;
  }

  // Attach a facet to this object
  attachFacet<T extends Facet>(FacetClass: FacetConstructor<T>, ...args: any[]): T {
    const facet = new FacetClass(...args);
    
    if (this.facets.has(FacetClass.facetType)) {
      throw new Error(`Facet ${FacetClass.facetType} already attached`);
    }
    
    this.facets.set(FacetClass.facetType, facet);
    return facet;
  }

  // Get a facet by its constructor
  getFacet<T extends Facet>(FacetClass: FacetConstructor<T>): T | undefined {
    const facet = this.facets.get(FacetClass.facetType);
    return facet as T | undefined;
  }

  // Check if a facet is attached
  hasFacet<T extends Facet>(FacetClass: FacetConstructor<T>): boolean {
    return this.facets.has(FacetClass.facetType);
  }

  // Remove a facet
  removeFacet<T extends Facet>(FacetClass: FacetConstructor<T>): boolean {
    return this.facets.delete(FacetClass.facetType);
  }

  // Get the core object
  getCore(): TCore {
    return this.core;
  }

  // Execute operation with facet requirement checking
  withFacet<T extends Facet, R>(
    FacetClass: FacetConstructor<T>,
    operation: (facet: T) => R
  ): R {
    const facet = this.getFacet(FacetClass);
    if (!facet) {
      throw new Error(`Required facet ${FacetClass.facetType} not found`);
    }
    return operation(facet);
  }

  // Get all attached facet types
  getAttachedFacetTypes(): string[] {
    return Array.from(this.facets.keys());
  }
}

// Example domain objects
interface Employee {
  name: string;
  id: string;
  department: string;
  email: string;
}

class EmployeeImpl implements Employee {
  constructor(
    public name: string,
    public id: string,
    public department: string,
    public email: string
  ) {}
}

// Account facet for financial operations
class AccountFacet implements Facet {
  static readonly facetType = 'account';
  readonly facetType = AccountFacet.facetType;

  private balance: number = 0;
  private accountNumber: string;
  private transactions: Transaction[] = [];

  constructor(accountNumber: string, initialBalance: number = 0) {
    this.accountNumber = accountNumber;
    this.balance = initialBalance;
  }

  deposit(amount: number): number {
    if (amount <= 0) {
      throw new Error('Deposit amount must be positive');
    }
    
    this.balance += amount;
    this.transactions.push({
      type: 'deposit',
      amount,
      timestamp: new Date(),
      balanceAfter: this.balance
    });
    
    return this.balance;
  }

  withdraw(amount: number): number {
    if (amount <= 0) {
      throw new Error('Withdrawal amount must be positive');
    }
    
    if (amount > this.balance) {
      throw new Error('Insufficient funds');
    }
    
    this.balance -= amount;
    this.transactions.push({
      type: 'withdrawal',
      amount,
      timestamp: new Date(),
      balanceAfter: this.balance
    });
    
    return this.balance;
  }

  getBalance(): number {
    return this.balance;
  }

  getAccountNumber(): string {
    return this.accountNumber;
  }

  getTransactionHistory(): Transaction[] {
    return [...this.transactions];
  }

  getRecentTransactions(count: number): Transaction[] {
    return this.transactions.slice(-count);
  }
}

interface Transaction {
  type: 'deposit' | 'withdrawal';
  amount: number;
  timestamp: Date;
  balanceAfter: number;
}

// Notification facet for alerting
class NotificationFacet implements Facet {
  static readonly facetType = 'notification';
  readonly facetType = NotificationFacet.facetType;

  private subscribers: Map<string, NotificationHandler[]> = new Map();

  subscribe(eventType: string, handler: NotificationHandler): void {
    if (!this.subscribers.has(eventType)) {
      this.subscribers.set(eventType, []);
    }
    this.subscribers.get(eventType)!.push(handler);
  }

  unsubscribe(eventType: string, handler: NotificationHandler): boolean {
    const handlers = this.subscribers.get(eventType);
    if (!handlers) return false;
    
    const index = handlers.indexOf(handler);
    if (index !== -1) {
      handlers.splice(index, 1);
      return true;
    }
    return false;
  }

  notify(eventType: string, data: any): void {
    const handlers = this.subscribers.get(eventType) || [];
    handlers.forEach(handler => {
      try {
        handler(eventType, data);
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : 'Unknown error';
        console.error(`Notification handler error for ${eventType}:`, errorMessage);
      }
    });
  }

  getSubscriberCount(eventType: string): number {
    return this.subscribers.get(eventType)?.length || 0;
  }
}

type NotificationHandler = (eventType: string, data: any) => void;

// Cache facet for performance optimization
class CacheFacet implements Facet {
  static readonly facetType = 'cache';
  readonly facetType = CacheFacet.facetType;

  private cache: Map<string, CacheEntry> = new Map();
  private maxSize: number;
  private defaultTTL: number;

  constructor(maxSize: number = 100, defaultTTL: number = 300000) { // 5 minutes default
    this.maxSize = maxSize;
    this.defaultTTL = defaultTTL;
  }

  set<T>(key: string, value: T, ttl?: number): void {
    // Remove oldest entries if cache is full
    if (this.cache.size >= this.maxSize) {
      const oldestKey = this.cache.keys().next().value;
      if (oldestKey !== undefined) {
        this.cache.delete(oldestKey);
      }
    }

    this.cache.set(key, {
      value,
      timestamp: Date.now(),
      ttl: ttl || this.defaultTTL
    });
  }

  get<T>(key: string): T | undefined {
    const entry = this.cache.get(key);
    if (!entry) return undefined;

    // Check if entry has expired
    if (Date.now() - entry.timestamp > entry.ttl) {
      this.cache.delete(key);
      return undefined;
    }

    return entry.value as T;
  }

  has(key: string): boolean {
    const entry = this.cache.get(key);
    if (!entry) return false;

    // Check if entry has expired
    if (Date.now() - entry.timestamp > entry.ttl) {
      this.cache.delete(key);
      return false;
    }

    return true;
  }

  invalidate(key: string): boolean {
    return this.cache.delete(key);
  }

  clear(): void {
    this.cache.clear();
  }

  getStats(): CacheStats {
    return {
      size: this.cache.size,
      maxSize: this.maxSize,
      hitRate: 0 // Would need to track hits/misses for real implementation
    };
  }
}

interface CacheEntry {
  value: any;
  timestamp: number;
  ttl: number;
}

interface CacheStats {
  size: number;
  maxSize: number;
  hitRate: number;
}

// Permission facet with role-based access control
class PermissionFacet implements Facet {
  static readonly facetType = 'permission';
  readonly facetType = PermissionFacet.facetType;

  private permissions: Set<string> = new Set();
  private role: string;

  constructor(role: string) {
    this.role = role;
    this.initializeRolePermissions(role);
  }

  private initializeRolePermissions(role: string): void {
    const rolePermissions: Record<string, string[]> = {
      'admin': ['read', 'write', 'delete', 'financial', 'admin'],
      'manager': ['read', 'write', 'financial', 'manage_team'],
      'employee': ['read', 'view_profile'],
      'guest': ['read']
    };

    const perms = rolePermissions[role] || [];
    perms.forEach(perm => this.permissions.add(perm));
  }

  hasPermission(permission: string): boolean {
    return this.permissions.has(permission);
  }

  grantPermission(permission: string): void {
    this.permissions.add(permission);
  }

  revokePermission(permission: string): void {
    this.permissions.delete(permission);
  }

  getPermissions(): string[] {
    return Array.from(this.permissions);
  }

  getRole(): string {
    return this.role;
  }

  requirePermission(permission: string): void {
    if (!this.hasPermission(permission)) {
      throw new Error(`Access denied: missing permission '${permission}'`);
    }
  }
}

// Composite operations using multiple facets
class EmployeeService {
  static performSecureFinancialOperation(
    employeeObj: FacetedObject<Employee>,
    operation: (account: AccountFacet) => number,
    operationType: string
  ): number {
    // Check permissions
    const permissions = employeeObj.getFacet(PermissionFacet);
    if (permissions) {
      permissions.requirePermission('financial');
    }

    // Perform operation
    const result = employeeObj.withFacet(AccountFacet, operation);

    // Send notification if facet is available
    const notifications = employeeObj.getFacet(NotificationFacet);
    if (notifications) {
      notifications.notify('financial_operation', {
        employee: employeeObj.getCore().name,
        operation: operationType,
        timestamp: new Date()
      });
    }

    // Invalidate related cache entries
    const cache = employeeObj.getFacet(CacheFacet);
    if (cache) {
      cache.invalidate(`balance_${employeeObj.getCore().id}`);
      cache.invalidate(`transactions_${employeeObj.getCore().id}`);
    }

    return result;
  }

  static getEmployeeSummary(employeeObj: FacetedObject<Employee>): string {
    const employee = employeeObj.getCore();
    const facetTypes = employeeObj.getAttachedFacetTypes();
    
    let summary = `Employee: ${employee.name} (${employee.id})\n`;
    summary += `Department: ${employee.department}\n`;
    summary += `Email: ${employee.email}\n`;
    summary += `Active Facets: ${facetTypes.join(', ')}\n`;

    // Add account information if available
    const account = employeeObj.getFacet(AccountFacet);
    if (account) {
      summary += `Account: ${account.getAccountNumber()} (Balance: $${account.getBalance().toFixed(2)})\n`;
      
      const recentTransactions = account.getRecentTransactions(3);
      if (recentTransactions.length > 0) {
        summary += 'Recent Transactions:\n';
        recentTransactions.forEach(tx => {
          summary += `  ${tx.type}: $${tx.amount.toFixed(2)} on ${tx.timestamp.toLocaleString()}\n`;
        });
      }
    }

    // Add permission information if available
    const permissions = employeeObj.getFacet(PermissionFacet);
    if (permissions) {
      summary += `Role: ${permissions.getRole()}\n`;
      summary += `Permissions: ${permissions.getPermissions().join(', ')}\n`;
    }

    // Add cache stats if available
    const cache = employeeObj.getFacet(CacheFacet);
    if (cache) {
      const stats = cache.getStats();
      summary += `Cache: ${stats.size}/${stats.maxSize} entries\n`;
    }

    return summary;
  }

  static configureEmployeeCapabilities(
    employeeObj: FacetedObject<Employee>,
    config: EmployeeConfig
  ): void {
    // Attach facets based on configuration
    if (config.hasAccount) {
      employeeObj.attachFacet(AccountFacet, config.accountNumber, config.initialBalance);
    }

    if (config.role) {
      employeeObj.attachFacet(PermissionFacet, config.role);
    }

    if (config.enableNotifications) {
      const notifications = employeeObj.attachFacet(NotificationFacet);
      
      // Set up default notification handlers
      notifications.subscribe('financial_operation', (eventType, data) => {
        console.log(`Financial operation performed: ${JSON.stringify(data)}`);
      });
    }

    if (config.enableCaching) {
      employeeObj.attachFacet(CacheFacet, config.cacheSize, config.cacheTTL);
    }
  }
}

interface EmployeeConfig {
  hasAccount?: boolean;
  accountNumber?: string;
  initialBalance?: number;
  role?: string;
  enableNotifications?: boolean;
  enableCaching?: boolean;
  cacheSize?: number;
  cacheTTL?: number;
}

// Usage example
function demonstrateFacetComposition(): void {
  console.log('=== Dynamic Facet Composition Demo ===');

  // Create an employee
  const employee = new EmployeeImpl('Bob Smith', 'EMP002', 'Finance', 'bob.smith@company.com');
  const employeeObj = new FacetedObject(employee);

  // Configure capabilities based on requirements
  EmployeeService.configureEmployeeCapabilities(employeeObj, {
    hasAccount: true,
    accountNumber: 'ACC002',
    initialBalance: 500,
    role: 'manager',
    enableNotifications: true,
    enableCaching: true,
    cacheSize: 50,
    cacheTTL: 600000 // 10 minutes
  });

  // Display initial summary
  console.log('\nInitial Employee Summary:');
  console.log(EmployeeService.getEmployeeSummary(employeeObj));

  // Perform financial operations
  try {
    const newBalance = EmployeeService.performSecureFinancialOperation(
      employeeObj,
      (account) => account.deposit(1000),
      'deposit'
    );
    console.log(`Deposit successful. New balance: $${newBalance.toFixed(2)}`);

    const finalBalance = EmployeeService.performSecureFinancialOperation(
      employeeObj,
      (account) => account.withdraw(200),
      'withdrawal'
    );
    console.log(`Withdrawal successful. Final balance: $${finalBalance.toFixed(2)}`);

  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
    console.error('Operation failed:', errorMessage);
  }

  // Display final summary
  console.log('\nFinal Employee Summary:');
  console.log(EmployeeService.getEmployeeSummary(employeeObj));
}

// Run the demonstration
demonstrateFacetComposition();