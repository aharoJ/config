
![](../../../z/aharo24%202023-03-07%20at%2012.29.42%20AM.png)

``` gio
why is it better to have false positives?
is it based on reality?
where you would hope its a false positive?
whats the target feature? or is there none? I have no clue on the ML you are doing
el_itachi — Today at 12:26 AM


Okay so here's the different types of results
True Positives: The model is correctly labeling these as the positive class (we found what we're looking for)
True Negatives: The model is correctly labeling these as the negative class (we didn't find what we're looking for)
False Positives: The model is incorrectly labeling these as the the positive class (we think we found what we're looking for but we didn't)
False Negatives: The model is incorrectly labeling these as the negative class (we think we didn't find what we're looking for but it is what we're looking for)
TP: Breast Cancer detected properly
TN: Breast Cancer not found properly
FP: Breast Cancer detected but not really there
FN: Breast Cancer not found but is actually there 
giode — Today at 12:27 AM
```


---
## GIO work

linear regression
```gio
class Model:
    def __init__(self, num_of_features):
        # Initial the weights
        self.weights = np.random.uniform(-50, 50, num_of_features).reshape(1, -1)

    def train(self, inputs, outputs, learning_rate=0.0001, epoch=250):
        loss_history = []
        weights_history = [np.copy(self.weights)]

        # Run the epoch
        for i in trange(epoch):

            # Use difference to calculate the MSE loss function
            difference = outputs - self.predict(inputs)
            loss = self._calculate_mean_square_error(difference)
            loss_history.append(loss)

            # Update the weights based on the gradient
            gradient = self._calculate_gradient(inputs, outputs)
            change = learning_rate * gradient
            self.weights = self.weights - change
            weights_history.append(np.copy(self.weights))

        return {
            'loss': loss_history,
            'weights': weights_history
        }

    @staticmethod
    def _calculate_mean_square_error(difference):
        # Calculate 1/m * sum(difference^2)
        return np.power(difference, 2).sum() / (2 * difference.shape[0])

    def _calculate_sqrt_mse(self, difference):
        # Take the sqrt of the mse
        return np.sqrt(self._calculate_mean_square_error(difference))

    def _calculate_gradient(self, inputs, outputs):
        difference = (self.predict(inputs) - outputs).flatten()
        return np.dot(difference, inputs) / (2 * inputs.shape[0])

    def predict(self, inputs):
        # Matrix Multiplication: X * W^T
        return np.dot(inputs, self.weights.T)

    def evaluate(self, test_inputs, test_outputs):
        difference = test_outputs - self.predict(test_inputs)
        return self._calculate_mean_square_error(difference)

    def get_weights(self):
        return self.weights
```

Log Regression (Binary Classification):
```gio
class Model:
    def __init__(self, num_of_features, threshold):
        # Initial the weights
        # self.weights = [1 for _ in range(num_of_features)]
        self.weights = np.ones(num_of_features).reshape(1, -1)
        self.threshold = threshold

    def train(self, inputs, outputs, learning_rate=0.0001, epoch=250):
        loss_history = []
        weights_history = [np.copy(self.weights)]

        # Run the epoch
        for _ in trange(epoch):
            # Calculate the Log Loss
            predictions = self.predict(inputs)
            loss = self.calculate_loss(outputs, predictions)
            loss_history.append(loss)

            # Update the weights based on the gradient
            gradient = self._calculate_gradient(inputs, outputs, predictions)
            self.weights = self.weights - learning_rate * gradient
            weights_history.append(np.copy(self.weights))

        return {
            'loss': loss_history,
            'weights': weights_history
        }

    @staticmethod
    def calculate_loss(outputs, predictions):
        return (-outputs * np.log(predictions) - (1 - outputs) * np.log(1 - predictions)).mean()

    @staticmethod
    def _calculate_gradient(inputs, outputs, predictions):
        difference = predictions - outputs
        return np.dot(difference, inputs) / inputs.shape[0]
        # return np.dot(difference, inputs).sum() / inputs.shape[0]

    def predict(self, inputs):
        # Matrix Multiplication: X * W^T and apply sigmoid
        # return self._sigmoid(np.dot(inputs, self.weights))
        return self._sigmoid(np.dot(inputs, self.weights.T)).flatten()

    @staticmethod
    def _sigmoid(z):
        return 1.0 / (1 + np.exp(-z, dtype=np.float64))

    def evaluate(self, test_inputs, test_outputs):
        predictions = self.predict(test_inputs)
        return self.calculate_loss(test_outputs, predictions)

    def get_weights(self):
        return self.weights
```

---



