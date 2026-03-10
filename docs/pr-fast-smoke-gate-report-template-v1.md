# PR Fast Smoke Gate Report Template v1

- For: #705

## 메타
- Date:
- Runner:
- Branch / Commit:
- PR:

## Summary
| Axis | Status | Auto/Manual | Evidence | Bucket |
| --- | --- | --- | --- | --- |
| `FS-001 map_root_ui` | PASS | Auto | `FeatureRegressionUITests` | - |
| `FS-002 widget_layout` | PASS | Auto | `widget layout checks` | - |
| `FS-003 widget_action` | PASS | Auto | `widget action regression` | - |
| `FS-004 watch_basic_action` | SKIPPED | Manual | `watch 영향 없음` | - |
| `FS-005 sync_recovery` | PASS | Auto | `backend_pr_check + auth smoke` | - |

## Detail
| Scenario ID | Command / Surface | Expected | Actual | Evidence Link / Log | Owner | Next Action |
| --- | --- | --- | --- | --- | --- | --- |
| `FS-001` | `FeatureRegressionUITests` | 지도 primary action 가림 없음 |  |  |  |  |
| `FS-002` | widget family checks | clipping 없음 |  |  |  |  |
| `FS-003` | widget action regression | start/end 상태 수렴 |  |  |  |  |
| `FS-004` | watch basic action | start/addPoint/end 확인 |  |  |  |  |
| `FS-005` | backend/auth smoke | member auth + nearby 복구 성공 |  |  |  |  |

## Failure Triage
- First failing bucket:
- First failing step:
- Retry attempted:
- Retry result:
- Escalation issue:

## Final Decision
- Gate Result: `GO | NO-GO`
- Blocking Items:
- Follow-up Actions:
