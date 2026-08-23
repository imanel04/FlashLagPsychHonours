
data {
  int<lower=0> N;                 // number of data points
  int<lower=0> n_subjects;        // number of subjects
  array[N] int id;                // subject ID  
  vector[N] y;                    // response variable
  
  // Prior hyperparameters
  real sigma_theta_mean;                 // prior hyperparameter for populativ-level standard deviation 1 (a_sigma)
  real<lower=0> sigma_theta_sd;          // prior hyperparameter for population level standard deviation 2 (b_sigma)
}


parameters {
  vector [n_subjects] theta;          // subject-specific intercepts, note: constrain to zero or no?
  real <offset = sigma_theta_mean, multiplier = sigma_theta_sd> sigma_theta_hat;   // population level standard deviation
  real<lower=0> sigma_epsilon;                                                     // standard deviation of the response variable
}

transformed parameters {
  real <lower = 0> sigma_theta = exp(sigma_theta_hat);  // prior log normal distributed
}


model {
  // Priors
  target += normal_lpdf(sigma_theta_hat | sigma_theta_mean, sigma_theta_sd);
  target += normal_lpdf(theta | 0,  sigma_theta);
  target += log(1/sigma_epsilon^2); // Jeffreys prior on sigma2
  
  // Likelihood
  target += normal_lpdf(y | theta[id], sigma_epsilon);
}

