Example 4.
``` java
void reverse(int[] array) {
    for (int i = 0; i < array.length / 2; i++) {
        int other = array.length - i - 1;
        int temp = array[i];
        array[i] = array[other];
        array[other] = temp;
    }
}
```
time complexity:  O(N)

visual breakdown of code
``` java
Initial array: [1, 2, 3, 4, 5]

i = 0:
- other = 4
- temp = 1
- array[0] = 5, array[4] = 1
Array after step 1: [5, 2, 3, 4, 1]

i = 1:
- other = 3
- temp = 2
- array[1] = 4, array[3] = 2
Array after step 2: [5, 4, 3, 2, 1]

i = 2: (no swap needed, as we've already swapped all elements)
- other = 2
- temp = 3
- array[2] = 3, array[2] = 3

Final reversed array: [5, 4, 3, 2, 1]
```


in python 
``` python
def reverse(array):
    # Iterate over half of the input array
    for i in range(len(array) // 2):
        # Compute the index of the corresponding element in the second half of the array
        other = len(array) - i - 1
        # Swap the current element with its corresponding element in the second half
        temp = array[i]
        array[i] = array[other]
        array[other] = temp

```