use std::collections::HashMap;
use std::any::{Any, TypeId};
use std::sync::RwLock;

// Core facet trait that all facets must implement
pub trait Facet: Any + Send + Sync {
    fn as_any(&self) -> &dyn Any;
    fn as_any_mut(&mut self) -> &mut dyn Any;
}

// Faceted object that can have facets attached
pub struct FacetedObject {
    facets: RwLock<HashMap<TypeId, Box<dyn Facet>>>,
    core_object: Box<dyn Any + Send + Sync>,
}

impl FacetedObject {
    pub fn new<T: Any + Send + Sync>(core: T) -> Self {
        Self {
            facets: RwLock::new(HashMap::new()),
            core_object: Box::new(core),
        }
    }

    // Attach a facet to this object
    pub fn attach_facet<F: Facet + 'static>(&self, facet: F) -> Result<(), String> {
        let type_id = TypeId::of::<F>();
        let mut facets = self.facets.write()
            .map_err(|_| "Failed to acquire write lock")?;
        
        if facets.contains_key(&type_id) {
            return Err(format!("Facet of type {:?} already attached", type_id));
        }
        
        facets.insert(type_id, Box::new(facet));
        Ok(())
    }

    // Execute an operation that requires a specific facet (safe callback pattern)
    pub fn with_facet<F: Facet + 'static, R>(
        &self, 
        operation: impl FnOnce(&F) -> R
    ) -> Result<R, String> {
        let facets = self.facets.read()
            .map_err(|_| "Failed to acquire read lock")?;
        let type_id = TypeId::of::<F>();
        
        if let Some(facet) = facets.get(&type_id) {
            if let Some(typed_facet) = facet.as_any().downcast_ref::<F>() {
                Ok(operation(typed_facet))
            } else {
                Err("Failed to downcast facet".to_string())
            }
        } else {
            Err(format!("Required facet not found: {:?}", type_id))
        }
    }

    // Execute a mutable operation on a facet
    pub fn with_facet_mut<F: Facet + 'static, R>(
        &self,
        operation: impl FnOnce(&mut F) -> R
    ) -> Result<R, String> {
        let mut facets = self.facets.write()
            .map_err(|_| "Failed to acquire write lock")?;
        let type_id = TypeId::of::<F>();
        
        if let Some(facet) = facets.get_mut(&type_id) {
            if let Some(typed_facet) = facet.as_any_mut().downcast_mut::<F>() {
                Ok(operation(typed_facet))
            } else {
                Err("Failed to downcast facet".to_string())
            }
        } else {
            Err(format!("Required facet not found: {:?}", type_id))
        }
    }

    // Check if a facet is attached
    pub fn has_facet<F: Facet + 'static>(&self) -> bool {
        let facets = self.facets.read().unwrap();
        let type_id = TypeId::of::<F>();
        facets.contains_key(&type_id)
    }

    // Get the core object
    pub fn get_core<T: 'static>(&self) -> Option<&T> {
        self.core_object.downcast_ref::<T>()
    }
}

// Example domain object
#[derive(Debug)]
pub struct Employee {
    pub name: String,
    pub id: String,
    pub department: String,
}

impl Employee {
    pub fn new(name: &str, id: &str, department: &str) -> Self {
        Self {
            name: name.to_string(),
            id: id.to_string(),
            department: department.to_string(),
        }
    }
}

// Account facet for financial operations
#[derive(Debug)]
pub struct AccountFacet {
    balance: f64,
    account_number: String,
}

impl AccountFacet {
    pub fn new(account_number: &str) -> Self {
        Self {
            balance: 0.0,
            account_number: account_number.to_string(),
        }
    }

    pub fn deposit(&mut self, amount: f64) -> Result<f64, String> {
        if amount <= 0.0 {
            return Err("Deposit amount must be positive".to_string());
        }
        self.balance += amount;
        Ok(self.balance)
    }

    pub fn withdraw(&mut self, amount: f64) -> Result<f64, String> {
        if amount <= 0.0 {
            return Err("Withdrawal amount must be positive".to_string());
        }
        if amount > self.balance {
            return Err("Insufficient funds".to_string());
        }
        self.balance -= amount;
        Ok(self.balance)
    }

    pub fn get_balance(&self) -> f64 {
        self.balance
    }

    pub fn get_account_number(&self) -> &str {
        &self.account_number
    }
}

impl Facet for AccountFacet {
    fn as_any(&self) -> &dyn Any {
        self
    }

    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
}

// Audit trail facet for tracking operations
#[derive(Debug)]
pub struct AuditFacet {
    entries: Vec<AuditEntry>,
}

#[derive(Debug, Clone)]
pub struct AuditEntry {
    timestamp: std::time::SystemTime,
    operation: String,
    details: String,
}

impl AuditFacet {
    pub fn new() -> Self {
        Self {
            entries: Vec::new(),
        }
    }

    pub fn log_operation(&mut self, operation: &str, details: &str) {
        self.entries.push(AuditEntry {
            timestamp: std::time::SystemTime::now(),
            operation: operation.to_string(),
            details: details.to_string(),
        });
    }

    pub fn get_audit_trail(&self) -> &[AuditEntry] {
        &self.entries
    }

    pub fn get_recent_entries(&self, count: usize) -> &[AuditEntry] {
        let start = if self.entries.len() > count {
            self.entries.len() - count
        } else {
            0
        };
        &self.entries[start..]
    }
}

impl Facet for AuditFacet {
    fn as_any(&self) -> &dyn Any {
        self
    }

    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
}

// Permission facet for access control
#[derive(Debug)]
pub struct PermissionFacet {
    permissions: HashMap<String, bool>,
    role: String,
}

impl PermissionFacet {
    pub fn new(role: &str) -> Self {
        let mut permissions = HashMap::new();
        
        // Define role-based permissions
        match role {
            "admin" => {
                permissions.insert("read".to_string(), true);
                permissions.insert("write".to_string(), true);
                permissions.insert("delete".to_string(), true);
                permissions.insert("financial_operations".to_string(), true);
            },
            "manager" => {
                permissions.insert("read".to_string(), true);
                permissions.insert("write".to_string(), true);
                permissions.insert("financial_operations".to_string(), true);
            },
            "employee" => {
                permissions.insert("read".to_string(), true);
            },
            _ => {}
        }

        Self {
            permissions,
            role: role.to_string(),
        }
    }

    pub fn has_permission(&self, permission: &str) -> bool {
        self.permissions.get(permission).copied().unwrap_or(false)
    }

    pub fn grant_permission(&mut self, permission: &str) {
        self.permissions.insert(permission.to_string(), true);
    }

    pub fn revoke_permission(&mut self, permission: &str) {
        self.permissions.insert(permission.to_string(), false);
    }

    pub fn get_role(&self) -> &str {
        &self.role
    }
}

impl Facet for PermissionFacet {
    fn as_any(&self) -> &dyn Any {
        self
    }

    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
}

// Composite operations that work across facets
pub struct EmployeeOperations;

impl EmployeeOperations {
    pub fn perform_financial_operation<F>(
        employee_obj: &FacetedObject,
        mut operation: F,
    ) -> Result<String, String> 
    where
        F: FnMut(&mut AccountFacet) -> Result<f64, String>,
    {
        // Check permissions first
        let has_permission = employee_obj.with_facet::<PermissionFacet, bool>(|permissions| {
            permissions.has_permission("financial_operations")
        }).unwrap_or(false);

        if !has_permission {
            return Err("Access denied: insufficient permissions for financial operations".to_string());
        }

        // Get employee info for logging
        let employee_name = employee_obj.get_core::<Employee>()
            .map(|emp| emp.name.clone())
            .unwrap_or_else(|| "Unknown".to_string());

        // Perform the operation
        let result = employee_obj.with_facet_mut::<AccountFacet, Result<f64, String>>(|account| {
            operation(account)
        })?;

        let balance = result?;

        // Log the operation if audit facet is present
        let _ = employee_obj.with_facet_mut::<AuditFacet, ()>(|audit| {
            audit.log_operation("financial_operation", &format!("New balance: {}", balance));
        });

        Ok(format!("Financial operation completed for {}. New balance: {}", employee_name, balance))
    }

    pub fn get_employee_summary(employee_obj: &FacetedObject) -> String {
        let mut summary = String::new();

        // Core employee information
        if let Some(employee) = employee_obj.get_core::<Employee>() {
            summary.push_str(&format!("Employee: {} (ID: {})\n", employee.name, employee.id));
            summary.push_str(&format!("Department: {}\n", employee.department));
        }

        // Account information if available
        let account_info = employee_obj.with_facet::<AccountFacet, String>(|account| {
            format!("Account: {} (Balance: ${:.2})\n", 
                account.get_account_number(), account.get_balance())
        }).unwrap_or_else(|_| "No account information\n".to_string());
        summary.push_str(&account_info);

        // Permission information if available
        let permission_info = employee_obj.with_facet::<PermissionFacet, String>(|permissions| {
            format!("Role: {}\n", permissions.get_role())
        }).unwrap_or_else(|_| "No permission information\n".to_string());
        summary.push_str(&permission_info);

        // Audit information if available
        let audit_info = employee_obj.with_facet::<AuditFacet, String>(|audit| {
            let recent_entries = audit.get_recent_entries(3);
            if !recent_entries.is_empty() {
                let mut info = "Recent Activity:\n".to_string();
                for entry in recent_entries {
                    info.push_str(&format!("  - {:?}: {} ({})\n", 
                        entry.timestamp,
                        entry.operation, 
                        entry.details));
                }
                info
            } else {
                "No recent activity\n".to_string()
            }
        }).unwrap_or_else(|_| "No audit information\n".to_string());
        summary.push_str(&audit_info);

        summary
    }
}

// Usage example
fn example_usage() -> Result<(), String> {
    println!("=== Dynamic Facets Example ===");

    // Create an employee
    let employee = Employee::new("Alice Johnson", "EMP001", "Engineering");
    let employee_obj = FacetedObject::new(employee);

    // Attach different facets based on requirements
    employee_obj.attach_facet(AccountFacet::new("ACC001"))?;
    employee_obj.attach_facet(PermissionFacet::new("manager"))?;
    employee_obj.attach_facet(AuditFacet::new())?;

    println!("Facets attached successfully!");

    // Use facets through the composite object
    let summary = EmployeeOperations::get_employee_summary(&employee_obj);
    println!("\nEmployee Summary:\n{}", summary);

    // Attempt financial operation (deposit)
    let result = EmployeeOperations::perform_financial_operation(
        &employee_obj,
        |account| account.deposit(1000.0)
    )?;
    println!("Deposit result: {}", result);

    // Attempt another financial operation (withdrawal)
    let result = EmployeeOperations::perform_financial_operation(
        &employee_obj,
        |account| account.withdraw(250.0)
    )?;
    println!("Withdrawal result: {}", result);

    // Display final summary
    let final_summary = EmployeeOperations::get_employee_summary(&employee_obj);
    println!("\nFinal Employee Summary:\n{}", final_summary);

    Ok(())
}

fn main() {
    match example_usage() {
        Ok(_) => println!("\nFacet composition example completed successfully."),
        Err(e) => eprintln!("Error: {}", e),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_facet_attachment() {
        let employee = Employee::new("Test User", "TEST001", "Engineering");
        let employee_obj = FacetedObject::new(employee);

        // Test attaching facets
        assert!(employee_obj.attach_facet(AccountFacet::new("ACC001")).is_ok());
        assert!(employee_obj.has_facet::<AccountFacet>());

        // Test duplicate attachment fails
        assert!(employee_obj.attach_facet(AccountFacet::new("ACC002")).is_err());
    }

    #[test]
    fn test_financial_operations() {
        let employee = Employee::new("Test User", "TEST001", "Engineering");
        let employee_obj = FacetedObject::new(employee);

        employee_obj.attach_facet(AccountFacet::new("ACC001")).unwrap();
        employee_obj.attach_facet(PermissionFacet::new("manager")).unwrap();

        // Test deposit
        let result = employee_obj.with_facet_mut::<AccountFacet, Result<f64, String>>(|account| {
            account.deposit(1000.0)
        }).unwrap();

        assert_eq!(result.unwrap(), 1000.0);

        // Test balance check
        let balance = employee_obj.with_facet::<AccountFacet, f64>(|account| {
            account.get_balance()
        }).unwrap();

        assert_eq!(balance, 1000.0);
    }

    #[test]
    fn test_permission_checking() {
        let employee = Employee::new("Test User", "TEST001", "Engineering");
        let employee_obj = FacetedObject::new(employee);

        employee_obj.attach_facet(PermissionFacet::new("employee")).unwrap();

        let has_financial = employee_obj.with_facet::<PermissionFacet, bool>(|permissions| {
            permissions.has_permission("financial_operations")
        }).unwrap();

        assert_eq!(has_financial, false);

        let has_read = employee_obj.with_facet::<PermissionFacet, bool>(|permissions| {
            permissions.has_permission("read")
        }).unwrap();

        assert_eq!(has_read, true);
    }
}
