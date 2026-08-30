removed {
  from = github_membership.member

  lifecycle {
    destroy = false
  }
}

removed {
  from = github_team.team

  lifecycle {
    destroy = false
  }
}

removed {
  from = github_team_membership.member

  lifecycle {
    destroy = false
  }
}

removed {
  from = github_team_repository.access

  lifecycle {
    destroy = false
  }
}
