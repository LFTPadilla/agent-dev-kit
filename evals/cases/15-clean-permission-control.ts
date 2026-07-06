type User = { id: string; orgId: string; role: 'owner' | 'admin' | 'member' }
type Project = { id: string; orgId: string }

export function canDeleteProject(user: User, project: Project) {
  if (user.orgId !== project.orgId) return false
  return user.role === 'owner' || user.role === 'admin'
}
