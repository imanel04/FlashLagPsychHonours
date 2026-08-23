data {
  int<lower=0> N;                 // number of data points
  int<lower=0> n_subjects;        // number of subjects
  array[N] int id;                      // subject ID  
  vector[N] y;                    // response variable

  // Prior settings for theta
  real theta_mean;                  // mean of the prior for theta
  real<lower=0> theta_sd;      // standard deviation of the prior for theta
}

transformed data {
  int n_trials = N / n_subjects;  // number of data points
}

parameters {
  real<offset=theta_mean,multiplier=theta_sd> theta_hat;
  real<lower=0> sigma_epsilon;    // standard deviation of the response variable
}

transformed parameters {
  real theta = exp(theta_hat);  // theta as log normal distribution
}

model {
  // Priors
  target += normal_lpdf(theta_hat | theta_mean, theta_sd);

  target += log(1/sigma_epsilon^2); // Jeffreys prior on sigma2

  // Likelihood
  target += normal_lpdf(y | theta, sigma_epsilon);
}
