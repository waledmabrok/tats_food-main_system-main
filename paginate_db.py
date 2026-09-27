import os
import re

db_path = 'lib/core/database/database_helper.dart'
with open(db_path, 'r') as f:
    content = f.read()

# For getSuppliers, getCustomers, getRawMaterials, getEmployees, etc.
# We will just replace `({bool activeOnly = true}) =>` with `({bool activeOnly = true, int? limit, int? offset}) =>`
# And add `limit: limit, offset: offset` to the query call.

patterns = [
    (r'Future<List<Map<String, dynamic>>> getSuppliers\(\{bool activeOnly = true\}\) =>\s*query\(\s*\'suppliers\',\s*where: activeOnly \? \'is_active = 1\' : null,\s*orderBy: \'name ASC\',',
     r"Future<List<Map<String, dynamic>>> getSuppliers({bool activeOnly = true, int? limit, int? offset}) =>\n      query(\n        'suppliers',\n        where: activeOnly ? 'is_active = 1' : null,\n        orderBy: 'name ASC',\n        limit: limit,\n        offset: offset,"),

    (r'Future<List<Map<String, dynamic>>> getCustomers\(\{bool activeOnly = true\}\) =>\s*query\(\s*\'customers\',\s*where: activeOnly \? \'is_active = 1\' : null,\s*orderBy: \'name ASC\',',
     r"Future<List<Map<String, dynamic>>> getCustomers({bool activeOnly = true, int? limit, int? offset}) =>\n      query(\n        'customers',\n        where: activeOnly ? 'is_active = 1' : null,\n        orderBy: 'name ASC',\n        limit: limit,\n        offset: offset,"),

    (r'Future<List<Map<String, dynamic>>> getRawMaterials\(\{\s*bool activeOnly = true,\s*\}\) =>\s*query\(\s*\'raw_materials\',\s*where: activeOnly \? \'is_active = 1\' : null,\s*orderBy: \'name ASC\',',
     r"Future<List<Map<String, dynamic>>> getRawMaterials({\n    bool activeOnly = true,\n    int? limit,\n    int? offset,\n  }) =>\n      query(\n        'raw_materials',\n        where: activeOnly ? 'is_active = 1' : null,\n        orderBy: 'name ASC',\n        limit: limit,\n        offset: offset,"),

    (r'Future<List<Map<String, dynamic>>> getEmployees\(\{bool activeOnly = true\}\) =>\s*query\(\s*\'employees\',\s*where: activeOnly \? \'is_active = 1\' : null,\s*orderBy: \'name ASC\',',
     r"Future<List<Map<String, dynamic>>> getEmployees({bool activeOnly = true, int? limit, int? offset}) =>\n      query(\n        'employees',\n        where: activeOnly ? 'is_active = 1' : null,\n        orderBy: 'name ASC',\n        limit: limit,\n        offset: offset,")
]

for p, r in patterns:
    content = re.sub(p, r, content)

with open(db_path, 'w') as f:
    f.write(content)

print("DB Helper updated.")
