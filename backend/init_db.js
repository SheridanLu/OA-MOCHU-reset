/**
 * 数据库初始化脚本
 * 创建 OA 系统所有核心表
 */

const Database = require('better-sqlite3');
const path = require('path');
const fs = require('fs');

// 确保数据目录存在
const dataDir = path.join(__dirname, '..', 'data');
if (!fs.existsSync(dataDir)) {
  fs.mkdirSync(dataDir, { recursive: true });
}

const dbPath = process.env.DB_PATH || path.join(dataDir, 'oa.db');
const db = new Database(dbPath);

// 启用外键约束
db.pragma('foreign_keys = ON');

console.log('📦 初始化数据库:', dbPath);

// ============================================
// 1. 部门表 (无限级树形结构)
// ============================================
db.exec(`
  CREATE TABLE IF NOT EXISTS dept (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(100) NOT NULL COMMENT '部门名称',
    parent_id INTEGER DEFAULT NULL COMMENT '父部门ID',
    level INTEGER NOT NULL DEFAULT 1 COMMENT '层级深度',
    path VARCHAR(500) NOT NULL DEFAULT '/' COMMENT '路径，如 /1/2/3/',
    sort INTEGER NOT NULL DEFAULT 0 COMMENT '排序',
    leader_id INTEGER DEFAULT NULL COMMENT '部门负责人ID',
    remark VARCHAR(500) DEFAULT NULL COMMENT '备注',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (parent_id) REFERENCES dept(id)
  );
  
  CREATE INDEX IF NOT EXISTS idx_dept_parent ON dept(parent_id);
  CREATE INDEX IF NOT EXISTS idx_dept_path ON dept(path);
`);

// ============================================
// 2. 用户表
// ============================================
db.exec(`
  CREATE TABLE IF NOT EXISTS user (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username VARCHAR(50) NOT NULL UNIQUE COMMENT '用户名',
    real_name VARCHAR(50) NOT NULL COMMENT '真实姓名',
    phone VARCHAR(20) UNIQUE COMMENT '手机号',
    email VARCHAR(100) DEFAULT NULL COMMENT '邮箱',
    password_hash VARCHAR(255) NOT NULL COMMENT '密码哈希',
    dept_id INTEGER DEFAULT NULL COMMENT '部门ID',
    position VARCHAR(50) DEFAULT NULL COMMENT '职位',
    status TINYINT NOT NULL DEFAULT 1 COMMENT '状态: 1启用 0禁用',
    flag_contact TINYINT NOT NULL DEFAULT 1 COMMENT '通讯录可见: 1是 0否',
    login_attempts INTEGER NOT NULL DEFAULT 0 COMMENT '登录失败次数',
    lock_until DATETIME DEFAULT NULL COMMENT '锁定截止时间',
    last_login_time DATETIME DEFAULT NULL COMMENT '最后登录时间',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (dept_id) REFERENCES dept(id)
  );
  
  CREATE INDEX IF NOT EXISTS idx_user_dept ON user(dept_id);
  CREATE INDEX IF NOT EXISTS idx_user_status ON user(status);
`);

// ============================================
// 3. 短信验证码表
// ============================================
db.exec(`
  CREATE TABLE IF NOT EXISTS sms_code (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone VARCHAR(20) NOT NULL COMMENT '手机号',
    code VARCHAR(6) NOT NULL COMMENT '验证码',
    expire_time DATETIME NOT NULL COMMENT '过期时间',
    used TINYINT NOT NULL DEFAULT 0 COMMENT '是否已使用: 1是 0否',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );
  
  CREATE INDEX IF NOT EXISTS idx_sms_phone ON sms_code(phone);
`);

// ============================================
// 4. 角色表
// ============================================
db.exec(`
  CREATE TABLE IF NOT EXISTS role (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code VARCHAR(50) NOT NULL UNIQUE COMMENT '角色编码',
    name VARCHAR(100) NOT NULL COMMENT '角色名称',
    description VARCHAR(500) DEFAULT NULL COMMENT '角色描述',
    data_scope VARCHAR(20) NOT NULL DEFAULT 'self' COMMENT '数据权限范围: all/dept/self/custom',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );
`);

// ============================================
// 5. 权限表
// ============================================
db.exec(`
  CREATE TABLE IF NOT EXISTS permission (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code VARCHAR(100) NOT NULL UNIQUE COMMENT '权限编码',
    name VARCHAR(100) NOT NULL COMMENT '权限名称',
    module VARCHAR(50) NOT NULL COMMENT '所属模块',
    type VARCHAR(20) NOT NULL DEFAULT 'function' COMMENT '类型: function/data',
    description VARCHAR(500) DEFAULT NULL COMMENT '权限描述',
    sort INTEGER NOT NULL DEFAULT 0 COMMENT '排序',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );
`);

// ============================================
// 6. 用户角色关联表
// ============================================
db.exec(`
  CREATE TABLE IF NOT EXISTS user_role (
    user_id INTEGER NOT NULL,
    role_id INTEGER NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, role_id),
    FOREIGN KEY (user_id) REFERENCES user(id),
    FOREIGN KEY (role_id) REFERENCES role(id)
  );
`);

// ============================================
// 7. 角色权限关联表
// ============================================
db.exec(`
  CREATE TABLE IF NOT EXISTS role_permission (
    role_id INTEGER NOT NULL,
    permission_id INTEGER NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (role_id, permission_id),
    FOREIGN KEY (role_id) REFERENCES role(id),
    FOREIGN KEY (permission_id) REFERENCES permission(id)
  );
`);

console.log('✅ 核心表创建完成');

// ============================================
// 插入默认部门数据
// ============================================
const insertDept = db.prepare(`
  INSERT OR IGNORE INTO dept (id, name, parent_id, level, path, sort)
  VALUES (?, ?, ?, ?, ?, ?)
`);

const departments = [
  { id: 1, name: '总公司', parent_id: null, level: 1, path: '/1/', sort: 0 },
  { id: 2, name: '工程项目管理部', parent_id: 1, level: 2, path: '/1/2/', sort: 1 },
  { id: 3, name: '基础业务部', parent_id: 1, level: 2, path: '/1/3/', sort: 2 },
  { id: 4, name: '软件业务部', parent_id: 1, level: 2, path: '/1/4/', sort: 3 },
  { id: 5, name: '财务/综合部', parent_id: 1, level: 2, path: '/1/5/', sort: 4 },
  { id: 6, name: '技术支撑部', parent_id: 1, level: 2, path: '/1/6/', sort: 5 },
];

for (const dept of departments) {
  insertDept.run(dept.id, dept.name, dept.parent_id, dept.level, dept.path, dept.sort);
}
console.log('✅ 默认部门数据插入完成');

// ============================================
// 插入默认角色数据
// ============================================
const insertRole = db.prepare(`
  INSERT OR IGNORE INTO role (id, code, name, description, data_scope)
  VALUES (?, ?, ?, ?, ?)
`);

const roles = [
  { id: 1, code: 'GM', name: '总经理', description: '公司最高管理者，拥有所有权限', data_scope: 'all' },
  { id: 2, code: 'PROJ_MGR', name: '项目经理', description: '负责项目管理', data_scope: 'self' },
  { id: 3, code: 'BUDGET', name: '预算员', description: '负责预算编制和成本控制', data_scope: 'self' },
  { id: 4, code: 'PURCHASE', name: '采购员', description: '负责采购和合同管理', data_scope: 'self' },
  { id: 5, code: 'DATA', name: '资料员', description: '负责文档和资料管理', data_scope: 'self' },
  { id: 6, code: 'FINANCE', name: '财务', description: '负责财务审批和付款', data_scope: 'self' },
  { id: 7, code: 'HR', name: '综合人员', description: '负责人事和行政', data_scope: 'self' },
  { id: 8, code: 'LEGAL', name: '法务', description: '负责合同法务审核', data_scope: 'self' },
  { id: 9, code: 'BASE', name: '基础部人员', description: '基础业务部成员', data_scope: 'self' },
  { id: 10, code: 'SOFT', name: '软件部人员', description: '软件业务部成员', data_scope: 'self' },
  { id: 11, code: 'TEAM_MEMBER', name: '普通员工', description: '项目团队成员', data_scope: 'self' },
];

for (const role of roles) {
  insertRole.run(role.id, role.code, role.name, role.description, role.data_scope);
}
console.log('✅ 默认角色数据插入完成');

// ============================================
// 插入默认管理员账号
// ============================================
const bcrypt = require('bcryptjs');
const defaultPassword = bcrypt.hashSync('admin123', 10);

const insertUser = db.prepare(`
  INSERT OR IGNORE INTO user (id, username, real_name, phone, password_hash, dept_id, position, status, flag_contact)
  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
`);

insertUser.run(1, 'admin', '系统管理员', '13800138000', defaultPassword, 1, '管理员', 1, 1);

// 为管理员分配总经理角色
const assignRole = db.prepare(`
  INSERT OR IGNORE INTO user_role (user_id, role_id) VALUES (?, ?)
`);
assignRole.run(1, 1); // admin -> GM

console.log('✅ 默认管理员账号创建完成 (admin/admin123)');

// ============================================
// 插入核心权限点
// ============================================
const insertPermission = db.prepare(`
  INSERT OR IGNORE INTO permission (id, code, name, module, type, description, sort)
  VALUES (?, ?, ?, ?, ?, ?, ?)
`);

const permissions = [
  // 项目管理
  { id: 1, code: 'project:create', name: '创建项目', module: 'project', type: 'function', description: '发起新项目立项', sort: 1 },
  { id: 2, code: 'project:approve', name: '审批项目', module: 'project', type: 'function', description: '审批项目立项申请', sort: 2 },
  { id: 3, code: 'project:convert', name: '虚拟转实体', module: 'project', type: 'function', description: '将虚拟项目转为实体项目', sort: 3 },
  { id: 4, code: 'project:terminate', name: '中止虚拟项目', module: 'project', type: 'function', description: '中止虚拟项目', sort: 4 },
  
  // 合同管理
  { id: 10, code: 'contract:sign-income', name: '签订收入合同', module: 'contract', type: 'function', description: '签订收入合同', sort: 10 },
  { id: 11, code: 'contract:sign-expense', name: '签订支出合同', module: 'contract', type: 'function', description: '签订支出合同', sort: 11 },
  { id: 12, code: 'contract:approve-finance', name: '财务审批合同', module: 'contract', type: 'function', description: '财务审批合同', sort: 12 },
  { id: 13, code: 'contract:approve-legal', name: '法务审批合同', module: 'contract', type: 'function', description: '法务审批合同', sort: 13 },
  
  // 物资管理
  { id: 20, code: 'material:purchase', name: '物资采购', module: 'material', type: 'function', description: '发起物资采购', sort: 20 },
  { id: 21, code: 'material:inbound', name: '物资入库', module: 'material', type: 'function', description: '物资入库', sort: 21 },
  { id: 22, code: 'material:outbound', name: '物资出库', module: 'material', type: 'function', description: '物资出库', sort: 22 },
  { id: 23, code: 'material:return', name: '物资退库', module: 'material', type: 'function', description: '物资退库', sort: 23 },
  
  // 财务管理
  { id: 30, code: 'finance:payment-labor', name: '人工费付款', module: 'finance', type: 'function', description: '人工费付款审批', sort: 30 },
  { id: 31, code: 'finance:payment-material', name: '材料款付款', module: 'finance', type: 'function', description: '材料款付款审批', sort: 31 },
  { id: 32, code: 'finance:statement', name: '对账单管理', module: 'finance', type: 'function', description: '对账单管理', sort: 32 },
  
  // 系统管理
  { id: 40, code: 'system:user', name: '用户管理', module: 'system', type: 'function', description: '用户管理', sort: 40 },
  { id: 41, code: 'system:role', name: '角色管理', module: 'system', type: 'function', description: '角色管理', sort: 41 },
  { id: 42, code: 'system:dept', name: '部门管理', module: 'system', type: 'function', description: '部门管理', sort: 42 },
];

for (const perm of permissions) {
  insertPermission.run(perm.id, perm.code, perm.name, perm.module, perm.type, perm.description, perm.sort);
}
console.log('✅ 核心权限点插入完成');

// 关闭数据库连接
db.close();
console.log('\n🎉 数据库初始化完成！');
