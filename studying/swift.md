

```swift
func turnAround() {
expert.turnLeft()
expert.turnLeft()
expert.moveForward()
expert.moveForward()
}
func completeSide() {
expert.moveForward()
expert.moveForward()
expert.collectGem()
}
for i in 1 ... 2 {
completeSide()
turnAround()
expert.turnRight()
}
completeSide()
expert.turnLockDown()
turnAround()
expert.turnRight()
for i in 1 ... 3 {
expert.moveForward()
}
expert.turnLeft()
for i in 1 ... 3 {
completeSide()
turnAround()
expert.turnLeft()
}
```