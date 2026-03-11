const express = require('express');
const router = express.Router();
const db = require('better-sqlite3')('../../data/oa.db');

/**
 * 递归构建部门树
 */
function buildTree(depts, parentId = null) {
  return depts
    .filter(d => d.parent_id === parentId)
    .map(d => ({
      id: d.id,
      name: d.name,
      parentId: d.parent_id,
      level: d.level,
      path: d.path,
      sort: d.sort,
      leaderId: d.leader_id,
      remark: d.remark,
      children: buildTree(depts, d.id)
    }))
    .sort((a, b) => a.sort - b.sort);
}

/**
 * GET /api/dept/tree
 * 获取完整部门树
 */
router.get('/tree', (req, res) => {
  try {
    const depts = db.prepare(`
      SELECT d.*, u.real_name as leader_name 
      FROM dept d 
      LEFT JOIN user u ON d.leader_id = u.id
      ORDER BY d.sort
    `).all();
    
    const tree = buildTree(depts);
    
    res.json({ code: 200, data: tree });
  } catch (err) {
    console.error(err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

/**
 * GET /api/dept/:id
 * 获取部门详情
 */
router.get('/:id', (req, res) => {
  try {
    const dept = db.prepare(`
      SELECT d.*, u.real_name as leader_name 
      FROM dept d 
      LEFT JOIN user u ON d.leader_id = u.id
      WHERE d.id = ?
    `).get(req.params.id);
    
    if (!dept) {
      return res.status(404).json({ code: 404, message: '部门不存在' });
    }
    
    res.json({ code: 200, data: dept });
  } catch (err) {
    console.error(err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

/**
 * POST /api/dept
 * 新增部门
 */
router.post('/', (req, res) => {
  const { name, parentId, sort, leaderId, remark } = req.body;
  
  if (!name) {
    return res.status(400).json({ code: 400, message: '部门名称不能为空' });
  }
  
  try {
    let level = 1;
    let path = '/';
    
    if (parentId) {
      const parent = db.prepare('SELECT * FROM dept WHERE id = ?').get(parentId);
      if (!parent) {
        return res.status(404).json({ code: 404, message: '父部门不存在' });
      }
      level = parent.level + 1;
      path = `${parent.path}`;
    }
    
    const result = db.prepare(`
      INSERT INTO dept (name, parent_id, level, path, sort, leader_id, remark)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(name, parentId || null, level, path, sort || 0, leaderId || null, remark || null);
    
    // 更新 path，加入自己的 ID
    const newId = result.lastInsertRowid;
    const newPath = `${path}${newId}/`;
    db.prepare('UPDATE dept SET path = ? WHERE id = ?').run(newPath, newId);
    
    res.json({ 
      code: 200, 
      message: '创建成功',
      data: { id: newId, path: newPath }
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

/**
 * PUT /api/dept/:id
 * 编辑部门
 */
router.put('/:id', (req, res) => {
  const { name, sort, leaderId, remark } = req.body;
  const deptId = req.params.id;
  
  if (!name) {
    return res.status(400).json({ code: 400, message: '部门名称不能为空' });
  }
  
  try {
    const dept = db.prepare('SELECT * FROM dept WHERE id = ?').get(deptId);
    if (!dept) {
      return res.status(404).json({ code: 404, message: '部门不存在' });
    }
    
    db.prepare(`
      UPDATE dept SET name = ?, sort = ?, leader_id = ?, remark = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ?
    `).run(name, sort || 0, leaderId || null, remark || null, deptId);
    
    res.json({ code: 200, message: '更新成功' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

/**
 * DELETE /api/dept/:id
 * 删除部门
 */
router.delete('/:id', (req, res) => {
  const deptId = req.params.id;
  
  try {
    // 检查是否有子部门
    const children = db.prepare('SELECT COUNT(*) as count FROM dept WHERE parent_id = ?').get(deptId);
    if (children.count > 0) {
      return res.status(400).json({ code: 400, message: '存在子部门，无法删除' });
    }
    
    // 检查是否有员工
    const users = db.prepare('SELECT COUNT(*) as count FROM user WHERE dept_id = ?').get(deptId);
    if (users.count > 0) {
      return res.status(400).json({ code: 400, message: '部门下存在员工，无法删除' });
    }
    
    db.prepare('DELETE FROM dept WHERE id = ?').run(deptId);
    
    res.json({ code: 200, message: '删除成功' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

/**
 * GET /api/dept/:id/children
 * 获取某部门的所有子孙部门
 */
router.get('/:id/children', (req, res) => {
  const deptId = req.params.id;
  
  try {
    const dept = db.prepare('SELECT * FROM dept WHERE id = ?').get(deptId);
    if (!dept) {
      return res.status(404).json({ code: 404, message: '部门不存在' });
    }
    
    // 使用 path 查询所有子孙部门
    const children = db.prepare(`
      SELECT d.*, u.real_name as leader_name 
      FROM dept d 
      LEFT JOIN user u ON d.leader_id = u.id
      WHERE d.path LIKE ? AND d.id != ?
      ORDER BY d.level, d.sort
    `).all(`${dept.path}%`, deptId);
    
    res.json({ code: 200, data: children });
  } catch (err) {
    console.error(err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

/**
 * GET /api/dept/:id/users
 * 获取部门下的用户
 */
router.get('/:id/users', (req, res) => {
  const deptId = req.params.id;
  const { includeChildren } = req.query;
  
  try {
    let users;
    
    if (includeChildren === 'true') {
      // 包含子部门的用户
      const dept = db.prepare('SELECT path FROM dept WHERE id = ?').get(deptId);
      if (!dept) {
        return res.status(404).json({ code: 404, message: '部门不存在' });
      }
      
      users = db.prepare(`
        SELECT u.id, u.username, u.real_name, u.phone, u.email, u.position, u.status, d.name as dept_name
        FROM user u
        JOIN dept d ON u.dept_id = d.id
        WHERE d.path LIKE ? AND u.status = 1
        ORDER BY u.real_name
      `).all(`${dept.path}%`);
    } else {
      // 仅当前部门
      users = db.prepare(`
        SELECT u.id, u.username, u.real_name, u.phone, u.email, u.position, u.status, d.name as dept_name
        FROM user u
        JOIN dept d ON u.dept_id = d.id
        WHERE u.dept_id = ? AND u.status = 1
        ORDER BY u.real_name
      `).all(deptId);
    }
    
    res.json({ code: 200, data: users });
  } catch (err) {
    console.error(err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

module.exports = router;
